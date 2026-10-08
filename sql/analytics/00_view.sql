create schema if not exists mart;

create or replace view mart.v_contributions as
select c.contribution_code, c.fiscal_year, c.pledge_amt, c.paid_amt,
       c.pledge_date, c.paid_date, c.raw_donor_code,
       a.donor_code, d.donor_name,
       f.pooled_fund_id, f.fund_name, f.fund_country_iso2
from core.cbpf_contributions c
join core.donor_alias    a on a.raw_donor_code = c.raw_donor_code
join core.dim_donor      d on d.donor_code     = a.donor_code
join core.dim_pooled_fund f on f.pooled_fund_id = c.pooled_fund_id
where c.is_active;