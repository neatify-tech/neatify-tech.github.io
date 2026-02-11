fn work() {
	let a = x + 1;
	let b = a * 2;
	let c = d + a + b;
	let out = source().map(|x| x + 1).filter(|x| x > 0).collect();
	let in = source()
		.map(|x| x + 1)
		.filter(|x| x > 0)
		.filter(|y| y == 0)
		.map(|a| a * 2)
		.doSomething()
		.when(true)
		.collect();
	out
}
