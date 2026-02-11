import java.util.function.Function;

class LambdaCast {
	public Function<Integer, Integer> run() {
		return (Function<Integer, Integer>)(x->x+1);
	}
}
