with df as (
    select donor_code, donor_name, pooled_fund_id, sum(paid_amt) as paid
    from mart.v_contributions
    where paid_amt > 0
    group by 1, 2, 3
)
select donor_name,
       count(*)                                  as funds,
       round(100 * max(paid) / sum(paid), 1)     as top_fund_pct
from df
group by donor_code, donor_name
order by sum(paid) desc
limit 15;