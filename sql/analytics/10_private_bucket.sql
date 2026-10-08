select raw_donor_code, count(*) as contributions,
       sum(pledge_amt) as pledged, sum(paid_amt) as paid
from mart.v_contributions
where donor_code = 17
group by raw_donor_code;