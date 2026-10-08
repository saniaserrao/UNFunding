COLS = ["pooled_fund_id", "raw_donor_code", "donor_country_code", "fiscal_year",
        "pledge_amt", "paid_amt", "pledge_date", "pipeline_date", "paid_date",
        "row_hash"]


def load_pooled_funds(conn, run_id):
    conn.execute("""
        insert into core.dim_pooled_fund
        select * from staging.v_pooled_fund
        on conflict (pooled_fund_id) do update set
            fund_name = excluded.fund_name,
            fund_abbrv = excluded.fund_abbrv,
            fund_country_iso2 = excluded.fund_country_iso2,
            latitude = excluded.latitude,
            longitude = excluded.longitude,
            parent_pooled_fund_id = excluded.parent_pooled_fund_id
    """)
    return {}


def load_contributions(conn, run_id):
    conn.execute("""
        insert into core.dim_donor
        select donor_code, donor_name, gms_donor_id from staging.v_donor
        on conflict (donor_code) do update set
            donor_name = excluded.donor_name,
            gms_donor_id = excluded.gms_donor_id
    """)
    conn.execute("""
        insert into core.donor_alias
        select raw_donor_code, donor_code from staging.v_donor_alias
        on conflict (raw_donor_code) do update set donor_code = excluded.donor_code
    """)
    conn.execute("create temp table cur on commit drop as "
                 "select * from staging.v_cbpf_contributions")

    cols = ", ".join(COLS)
    sets = ", ".join(f"{c} = excluded.{c}" for c in COLS)
    inserted, updated = conn.execute(f"""
        with up as (
            insert into core.cbpf_contributions as c
                (contribution_code, {cols}, first_seen_run_id, last_seen_run_id)
            select contribution_code, {cols}, %(r)s, %(r)s from cur
            on conflict (contribution_code) do update set
                {sets}, last_seen_run_id = %(r)s, is_active = true
            where c.row_hash <> excluded.row_hash
            returning (xmax = 0) as inserted
        )
        select count(*) filter (where inserted),
               count(*) filter (where not inserted)
        from up
    """, {"r": run_id}).fetchone()

    unchanged = conn.execute("""
        update core.cbpf_contributions c
        set last_seen_run_id = %s, is_active = true
        from cur
        where c.contribution_code = cur.contribution_code
          and c.last_seen_run_id <> %s
    """, (run_id, run_id)).rowcount

    missing = conn.execute("""
        update core.cbpf_contributions c set is_active = false
        where c.is_active and not exists
            (select 1 from cur where cur.contribution_code = c.contribution_code)
    """).rowcount

    return {"inserted": inserted, "updated": updated,
            "unchanged": unchanged, "missing": missing}


TRANSFORMS = {"poolfund": load_pooled_funds, "contribution": load_contributions}