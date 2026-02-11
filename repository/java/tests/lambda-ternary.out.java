import java.util.function.Function;

class LambdaTernary {
	public Function<Integer, Integer> pick(boolean ok) {
		return ok ? x -> x + 1 : x -> x + 2;
	}
}
