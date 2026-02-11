select
	id,
	name,
	created_at
from users
where active = true
	and created_at >= '2024-01-01'
order by created_at desc
limit 25;
