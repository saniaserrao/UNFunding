select fiscal_year, sum(pledge_amt) as pledged, sum(paid_amt) as paid
from mart.v_contributions
where fiscal_year > extract(year from current_date)
group by fiscal_year
order by fiscal_year;