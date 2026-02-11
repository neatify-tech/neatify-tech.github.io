import java.util.List;

class MethodReferenceChain {
	public void run(List<String> list) {
		list.stream()
			.map(String::trim)
			.forEach(System.out::println)
			.map(String::trim)
			.filter(s -> s.isEmpty());
	}
}
