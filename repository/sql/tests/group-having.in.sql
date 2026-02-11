select user_id,sum(amount) as total from payments where status='paid' group by user_id having sum(amount) > 100 order by total desc;
