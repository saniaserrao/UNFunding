select fiscal_year,
       sum(pledge_amt) as pledged,
       sum(paid_amt)   as paid,
       round(100 * sum(paid_amt) / nullif(sum(pledge_amt), 0), 1) as paid_share_pct
from mart.v_contributions
group by fiscal_year
order by fiscal_year;