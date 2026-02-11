with region_sales as (
	select
		region_id,
		sum(amount) as total
	from orders
	where status = 'paid'
	group by region_id
	having sum(amount) > 1000
),
top_regions as (
	select
		region_id
	from region_sales
)
select
	r.id,
	r.name,
	rs.total
from regions r
join region_sales rs
	on r.id = rs.region_id
where rs.total > 1000
	and r.active = true
order by rs.total desc;
