# Nested Fences

- Query:

```sql
select
	id,
	name
from users
where active = true;
```

- Payload:

```json
{
	"name": "Neatify",
	"flags": [
		true,
		false
	]
}
```

> Report:
>
>
> ```sql
> select user_id,sum(amount) as total from payments where status='paid' group by user_id having sum(amount) > 100 order by total desc;
> ```
>
>
>
> ```json
> {"numbers":[1,2,3],"meta":{"ok":true}}
> ```
