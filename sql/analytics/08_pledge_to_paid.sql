select donor_name,
       count(*) as n,
       percentile_cont(0.5) within group (order by paid_date - pledge_date) as median_days
from mart.v_contributions
where paid_date is not null and pledge_date is not null
  and paid_date >= pledge_date
group by donor_code, donor_name
having count(*) >= 20
order by median_days desc;

-- data check
select count(*) as paid_before_pledge
from mart.v_contributions
where paid_date < pledge_date;