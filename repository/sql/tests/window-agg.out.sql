select
	user_id,
	sum(amount) over (partition by user_id order by created_at) as running_total,
	avg(amount) over (partition by user_id) as avg_total
from payments
where status = 'paid'
order by
	user_id,
	created_at desc;
