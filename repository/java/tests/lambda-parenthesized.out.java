class LambdaParenthesized {
	public void run() {
		call((x -> x + 1));
	}

	private void call(java.util.function.Function<Integer, Integer> f) {
	}
}
