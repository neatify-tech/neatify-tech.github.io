select
	id,
	name
from users
where status in (
		'active',
		'trial',
		'paused'
	)
	and created_at >= '2023-01-01'
order by created_at desc;
