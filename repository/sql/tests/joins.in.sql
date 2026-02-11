select u.id,u.email,p.plan_name from users u left join plans p on u.plan_id=p.id where u.status in ('active','trial') and p.plan_name is not null;
