from psycopg.types.json import Jsonb


def load_raw(conn, run_id, source, rows):
    conn.execute(
        "insert into raw.api_pulls (source, row_count, payload, run_id) "
        "values (%s, %s, %s, %s)",
        (source, len(rows), Jsonb(rows), run_id),
    )