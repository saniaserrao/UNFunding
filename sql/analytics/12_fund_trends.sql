with fy as (
    select pooled_fund_id, fund_name, fiscal_year, sum(paid_amt) as paid
    from mart.v_contributions
    group by 1, 2, 3
)
select fund_name, fiscal_year, paid,
       paid - lag(paid) over (partition by pooled_fund_id order by fiscal_year) as change
from fy
order by fund_name, fiscal_year;