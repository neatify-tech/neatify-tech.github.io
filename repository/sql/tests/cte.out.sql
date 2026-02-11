with recent as (
	select
		id,
		user_id,
		amount
	from payments
	where status = 'paid'
),
totals as (
	select
		user_id,
		sum(amount) as total
	from recent
	group by user_id
)
select
	u.id,
	u.email,
	t.total
from users u
join totals t
	on u.id = t.user_id
where t.total > 100
order by t.total desc;
