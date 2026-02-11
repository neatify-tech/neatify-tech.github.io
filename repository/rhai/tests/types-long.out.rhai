let config: {
	path: string,
	retries: i64,
	flags: [bool],
	owners: [string],
	metadata: { id: i64, ok: bool, tags: [string] },
} = #{
	path: "x",
	retries: 3,
	flags: [true, false],
	owners: ["a", "b"],
	metadata: #{ id: 1, ok: true, tags: ["t1", "t2"] },
};
