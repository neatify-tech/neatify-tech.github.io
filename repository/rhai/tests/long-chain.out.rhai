let out = source()
	.map(|x| x + 1)
	.filter(|x| x > 0)
	.group_by(|x| x % 2)
	.map(|x| x * 2)
	.reduce(|a, b| a + b)
	.collect()
	.sum();
