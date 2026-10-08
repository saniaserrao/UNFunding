create or replace view staging.v_pooled_fund as
with latest as (
    select payload from raw.api_pulls
    where source = 'poolfund' order by pull_id desc limit 1
)
select (e->>'Id')::int                          as pooled_fund_id,
       e->>'PoolfundName'                       as fund_name,
       e->>'PoolfundCodeAbbrv'                  as fund_abbrv,
       e->>'CountryCode'                        as fund_country_iso2,
       (e->>'Latitude')::numeric(9,6)           as latitude,
       (e->>'Longitude')::numeric(9,6)          as longitude,
       nullif((e->>'ParentPFId')::int, 0)       as parent_pooled_fund_id
from latest, jsonb_array_elements(latest.payload) e;

create or replace view staging.v_contribution_json as
with latest as (
    select payload from raw.api_pulls
    where source = 'contribution' order by pull_id desc limit 1
)
select e from latest, jsonb_array_elements(latest.payload) e;

create or replace view staging.v_donor_alias as
select r.raw_donor_code,
       coalesce(o.donor_code, r.raw_donor_code) as donor_code
from (select distinct (e->>'DonorCode')::int as raw_donor_code
      from staging.v_contribution_json) r
left join (values (1011, 17), (1028, 1015)) as o(raw_donor_code, donor_code)
       using (raw_donor_code);

create or replace view staging.v_donor as
select distinct on (donor_code)
       (e->>'DonorCode')::int    as donor_code,
       e->>'DonorName'           as donor_name,
       (e->>'GMSDonorID')::int   as gms_donor_id
from staging.v_contribution_json
where (e->>'DonorCode')::int in (select donor_code from staging.v_donor_alias)
order by donor_code;