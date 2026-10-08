create or replace function staging.clean_date(t text) returns date
language sql immutable as $$
    select case when t >= '2000' then t::date end
$$;

create or replace view staging.v_cbpf_contributions as
with latest as (
    select payload
    from raw.api_pulls
    where source = 'contribution'
    order by pull_id desc
    limit 1
),
typed as (
    select
        e->>'ContributionCode'                      as contribution_code,
        (e->>'PooledFundId')::int                   as pooled_fund_id,
        (e->>'DonorCode')::int                      as raw_donor_code,
        e->>'CountryCode'                           as donor_country_code,
        (e->>'FiscalYear')::int                     as fiscal_year,
        (e->>'PledgeAmt')::numeric(18,2)            as pledge_amt,
        nullif((e->>'PaidAmt')::numeric(18,2), 0)   as paid_amt,
        staging.clean_date(e->>'PledgeDate')        as pledge_date,
        staging.clean_date(e->>'PipeLineDate')      as pipeline_date,
        staging.clean_date(e->>'PaidDate')          as paid_date
    from latest, jsonb_array_elements(latest.payload) e
)
select
    t.*,
    coalesce(a.donor_code, t.raw_donor_code) as donor_code,
    md5(row(
        t.pooled_fund_id,
        coalesce(a.donor_code, t.raw_donor_code),
        t.donor_country_code,
        t.fiscal_year,
        t.pledge_amt,
        t.paid_amt,
        t.pledge_date,
        t.pipeline_date,
        t.paid_date
    )::text) as row_hash
from typed t
left join core.donor_alias a using (raw_donor_code);