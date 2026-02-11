let out = wrap(items()
	.map(|x| {
		let y = prep(x)
			.trim()
			.to_int();
		y
	})
	.filter(|x| x > 0)
	.collect())
	.trim()
	.to_string();
