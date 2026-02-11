export {};
const list = ["a", "b"];
const veryLongConditionNameThatForcesWrapping = true;
const anotherVeryLongConditionNameThatForcesWrapping = false;
if (veryLongConditionNameThatForcesWrapping
		&& list.filter(item => item && item.startsWith("a"))
			.map(item => item.trim())
			.some(item => item && item.endsWith("z"))
		&& anotherVeryLongConditionNameThatForcesWrapping) {
	console.log("ok");
}
