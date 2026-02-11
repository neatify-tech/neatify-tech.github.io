class LambdaArgTernary {
	public void run(boolean ok) {
		use(ok ? x -> x + 1 : x -> x + 2);
	}

	private void use(java.util.function.Function<Integer, Integer> f) {
	}
}
