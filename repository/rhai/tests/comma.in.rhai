let root_doc = walk(
	"rust",
	kinds::list,
	// queries,,,
	|node, children| {
		build_doc(node, children)
	}
);
