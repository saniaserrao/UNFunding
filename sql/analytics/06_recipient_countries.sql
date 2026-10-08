with dc as (
    select donor_code, donor_name, fund_country_iso2, sum(paid_amt) as paid
    from mart.v_contributions
    where paid_amt is not null
    group by 1, 2, 3
), ranked as (
    select *, row_number() over (partition by donor_code order by paid desc) as rn
    from dc
)
select donor_name, fund_country_iso2, paid
from ranked
where rn <= 3
order by donor_name, rn;