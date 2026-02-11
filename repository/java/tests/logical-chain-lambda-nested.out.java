import java.util.List;

class LogicalChainLambdaNested {
	public boolean run(List<String> list) {
		boolean veryLongConditionNameThatForcesWrapping = true;
		boolean anotherVeryLongConditionNameThatForcesWrapping = false;
		if (veryLongConditionNameThatForcesWrapping
				&& list.stream()
					.anyMatch(s -> s != null && s.startsWith("a"))
				&& anotherVeryLongConditionNameThatForcesWrapping) {
			return true;
		}
		return false;
	}
}
