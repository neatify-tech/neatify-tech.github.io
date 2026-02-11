let out = data.trim()
	.to_int()
	.to_string()
	.back_to_int()
	.then_to_double()
	.filter(this()
		.should()
		.be
		.wrapped())
	.max(0)
	.doThis()
	.thenThat();
