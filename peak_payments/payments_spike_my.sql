with params as (
select DATE '2026-10-01' as start_date,
        DATE '2026-10-31' as end_date
)

,date_spine as(
select generate_series(p.start_date -INTERVAL '3 days', p.end_date- INTERVAL '1 day', INTERVAL '1 DAY')::DATE as txn_date
 from params as p
)


date_volume as (
select merchant_id , tran_date ,count(*) as tran_count
from payments pay
cross join params p
where pay.tran_date> =p.start_date- interval '3 days' and pay.tran_date < p.end_date
group by merchant_id , tran_date
)

,merchants  as (
select distinct merchant_id  from payments
)

,merchant_date_grid as (

select m.merchant_id, d.tran_date from merchants m cross join date_spine  d
)


filled_vol as (
select m.merchant_id , m.trans_date , coalesce(m.tran_count, 0) as tran_volume
from
merchant_date_grid m  left join date_volume dv
on   m.merchant_id = dv.merchant_id  and
m.tran_date= d.tran_date



)