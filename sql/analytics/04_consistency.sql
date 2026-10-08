select donor_name,
       count(distinct fiscal_year)                      as years_giving,
       min(fiscal_year)                                 as first_year,
       max(fiscal_year)                                 as last_year,
       round(count(distinct fiscal_year)::numeric
             / (max(fiscal_year) - min(fiscal_year) + 1), 2) as consistency
from mart.v_contributions
where paid_amt > 0
group by donor_code, donor_name
order by years_giving desc, donor_name;