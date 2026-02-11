import java.util.List;

class ChainLambdaSpacing {
	public List<Integer> run(List<Integer> list) {
		return list.stream()
			.map(x -> x + 1)
			.filter(x -> x % 2 == 0)
			.toList();
	}
}
