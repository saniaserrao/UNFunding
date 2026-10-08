import sys
import time

import psycopg
import requests

from db import connect
from extract import SOURCES, fetch
from load_raw import load_raw
from transform import TRANSFORMS


def fetch_retry(source, tries=3):
    for attempt in range(tries):
        try:
            return fetch(source)
        except (requests.ConnectionError, requests.Timeout):
            if attempt == tries - 1:
                raise
            time.sleep(30 * 2 ** attempt)


def run(source):
    with connect() as conn:
        got_lock = conn.execute(
            "select pg_try_advisory_lock(hashtext(%s))", (source,)
        ).fetchone()[0]
        if not got_lock:
            print(f"{source}: another run is active, skipping")
            return
        conn.execute(
            "update core.pipeline_runs set status = 'failed', finished_at = now(), "
            "error = 'abandoned: no finish recorded' "
            "where source = %s and status = 'running'",
            (source,),
        )
        run_id = conn.execute(
            "insert into core.pipeline_runs (source, source_as_of) "
            "values (%s, current_date) returning run_id",
            (source,),
        ).fetchone()[0]
        conn.commit()
        try:
            rows = fetch_retry(source)
            load_raw(conn, run_id, source, rows)
            conn.commit()
            counts = TRANSFORMS.get(source, lambda conn, run_id: {})(conn, run_id)
            conn.execute(
                "update core.pipeline_runs set status = 'success', finished_at = now(), "
                "rows_fetched = %s, inserted = %s, updated = %s, unchanged = %s, "
                "missing = %s where run_id = %s",
                (len(rows), counts.get("inserted"), counts.get("updated"),
                 counts.get("unchanged"), counts.get("missing"), run_id),
            )
            conn.commit()
        except Exception as e:
            try:
                conn.rollback()
                conn.execute(
                    "update core.pipeline_runs set status = 'failed', "
                    "finished_at = now(), error = %s where run_id = %s",
                    (str(e), run_id),
                )
                conn.commit()
            except psycopg.Error:
                pass  # DB unreachable; the next run closes this row as abandoned
            raise


if __name__ == "__main__":
    for source in sys.argv[1:] or SOURCES:
        run(source)