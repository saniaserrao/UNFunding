select donor_name,
       count(*)                                           as pledges,
       count(paid_amt)                                    as with_payment,
       round(100 * count(paid_amt)::numeric / count(*), 1) as pct_with_payment
from mart.v_contributions
where pledge_amt > 0
group by donor_code, donor_name
having count(*) >= 20
order by pledges desc;