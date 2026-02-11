with base as (
	select
		u.id,
		u.company_id,
		u.email,
		u.created_at,
		u.status,
		u.deleted_at,
		/*score*/u.score
	from users u
	where u.deleted_at is null
),
stats as (
	select
		o.user_id,
		sum(o.amount) as total,
		count(*) as cnt,
		max(o.created_at) as last_order_at
	from orders o
	where o.status != 'void'
	group by o.user_id
),
enriched as (
	select
		b.id,
		b.email,
		b.company_id,
		b.created_at,
		b.status,
		b.score,
		s.total,
		s.cnt,
		s.last_order_at,
		case
			when s.total >= 10000 then 'vip'
			when s.total >= 5000 then 'priority'
			else 'standard'
		end as tier,
		(
			select
				max(p.amount)
			from payments p
			where p.user_id = b.id
				and p.status = @payStatus
		) as last_payment
	from base b
	left join stats s
		on s.user_id = b.id
)
select
	e.id,
	/*final*/ e.email,
	-- main contact
	e.tier,
	(
		select
			count(*)
		from orders o2
		where o2.user_id = e.id
			and o2.status = @orderStatus
	) as order_count,
	(
		select
			sum(p2.amount)
		from payments p2
		where p2.user_id = e.id
			and p2.status != 'void'
	) as paid_total,
	(e.total*1.07 + e.score/10) as gross_score,
	case
		when e.status = 'active' and e.email = 'user@example.com' and e.score >= 9000 then 'Y'
		else 'N'
	end as active_flag
from enriched e
inner join companies c
	on c.id = e.company_id
		and c.active = (
			select
				max(active)
			from companies c2
			where c2.id = c.id
		)
left join regions r
	on r.id = c.region_id
		and r.code in (
			select
				code
			from region_allowlist ra
			where ra.company_id = c.id
		)
full outer join flags f
	on f.user_id = e.id
where e.deleted_at is null
	and e.tier != 'banned'
	and e.total >= $1
	and e.email = :email
	and c.name = $companyName
	and e.score >= ?
	and r.code = @regionCode
order by
	e.total desc,
	e.created_at asc
limit 100;
