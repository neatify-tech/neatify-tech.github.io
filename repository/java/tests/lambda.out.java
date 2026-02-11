public class File {
	public static void call(int...values) {
		Runnable m = s -> {
			System.out.println("test");
		};
		Runnable n = () -> {
			System.out.println("test");
		};
		Runnable o = s -> System.out.println("test");
		List.of()
			.stream()
			.filter(s -> {
				s.doIt();
				return false;
			})
			.map(s -> s.mapThisToSomethingElse())
			.map(s -> s.andThenToThis())
			.map(s -> s.andThisToo())
			.map(s -> s.dontForgetThis())
			.toList();
		stream.filter(s -> {
				s.doIt();
				return false;
			})
			.map(s -> s.simple())
			.toList();
	}
}
