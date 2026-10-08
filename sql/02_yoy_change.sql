with yearly as (
    select donor_code, donor_name, fiscal_year, sum(paid_amt) as total_paid
    from mart.v_contributions
    where paid_amt is not null
    group by 1, 2, 3
)
select donor_name, fiscal_year, total_paid,
       lag(total_paid) over w as prev_paid,
       round(100 * (total_paid - lag(total_paid) over w)
             / nullif(lag(total_paid) over w, 0), 1) as pct_change
from yearly
window w as (partition by donor_code order by fiscal_year)
order by donor_name, fiscal_year;
