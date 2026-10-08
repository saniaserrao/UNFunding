with yearly as (
    select donor_code, fiscal_year, sum(paid_amt) as total_paid
    from mart.v_contributions
    where paid_amt is not null
    group by 1, 2
), ranked as (
    select fiscal_year,
           rank() over (partition by fiscal_year order by total_paid desc) as rnk,
           total_paid / sum(total_paid) over (partition by fiscal_year) as share
    from yearly
)
select fiscal_year,
       round(100 * sum(share) filter (where rnk <= 5), 1)  as top5_pct,
       round(100 * sum(share) filter (where rnk <= 10), 1) as top10_pct
from ranked
group by fiscal_year
order by fiscal_year;