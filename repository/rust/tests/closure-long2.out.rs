engine.register_fn(
	"walk",
	move |ctx_call: NativeCallContext, language: &str, queries: Array, rule: FnPtr| -> RhaiResult<INT> {
		let mut query_list = Vec::new();
		for item in queries {
			let q = item.into_string().map_err(|_| "walk query list expects strings")?;
			if !q.trim().is_empty() {
				query_list.push(q);
			}
		}
		if query_list.is_empty() {
			return Ok(0);
		}
		let Some(lang) = ctx_walk_filtered.language_for(language) else {
			return Ok(0);
		};
		let Some(tree) = ctx_walk_filtered.tree_for(language) else {
			return Ok(0);
		};
		let source_bytes = ctx_walk_filtered.source_bytes();
		let root = tree.root_node();
		let mut marked: HashSet<NodeKey> = HashSet::new();
		let mut captured: HashSet<NodeKey> = HashSet::new();
		for q in query_list.iter() {
			let Some(query) = ctx_walk_filtered.cached_query(language, q, &lang) else {
				continue;
			};
			let mut cursor = QueryCursor::new();
			let mut matches = cursor.matches(&query, root, source_bytes.as_slice());
			while let Some(m) = matches.next() {
				for capture in m.captures.iter() {
					let node = capture.node;
					captured.insert(NodeKey::from_ts_node(&node));
					let mut current = Some(node);
					while let Some(n) = current {
						marked.insert(NodeKey::from_ts_node(&n));
						current = n.parent();
					}
				}
			}
		}
		marked.insert(NodeKey::from_ts_node(&root));
		let mut nodes: Vec<tree_sitter::Node> = Vec::new();
		let mut stack = vec![(root, false)];
		while let Some((node, visited)) = stack.pop() {
			let key = NodeKey::from_ts_node(&node);
			if !marked.contains(&key) {
				continue;
			}
			if visited {
				nodes.push(node);
				continue;
			}
			stack.push((node, true));
			let mut cursor = node.walk();
			if cursor.goto_first_child() {
				let mut children = Vec::new();
				loop {
					children.push(cursor.node());
					if !cursor.goto_next_sibling() {
						break;
					}
				}
				for child in children.into_iter().rev() {
					if marked.contains(&NodeKey::from_ts_node(&child)) {
						stack.push((child, false));
					}
				}
			}
		}
		if nodes.is_empty() {
			return Ok(0);
		}
		let docs: Rc<RefCell<HashMap<NodeKey, INT>>> = Rc::new(RefCell::new(HashMap::new()));
		ACTIVE_DOCS.with(
			|cell| {
				*cell.borrow_mut() = Some(docs.clone());
			}
		);
		for node in nodes.iter() {
			let key = NodeKey::from_ts_node(node);
			let doc_id: INT = if captured.contains(&key) {
				let mut child_docs = Array::new();
				let mut cursor = node.walk();
				if cursor.goto_first_child() {
					loop {
						let child = cursor.node();
						let child_key = NodeKey::from_ts_node(&child);
						if let Some(id) = docs.borrow().get(&child_key) {
							child_docs.push(Dynamic::from(*id));
						}
						else {
							child_docs.push(Dynamic::UNIT);
						}
						if !cursor.goto_next_sibling() {
							break;
						}
					}
				}
				let node_ref = ctx_walk_filtered.node_ref(*node, language);
				rule.call_within_context(&ctx_call, (node_ref, child_docs)).map_err(Box::<EvalAltResult>::from)?
			}
			else {
				ctx_walk_filtered.doc_range(node.start_byte(), node.end_byte()) as INT
			};
			docs.borrow_mut().insert(key, doc_id);
		}
		let root_key = NodeKey::from_ts_node(nodes.last().unwrap());
		let doc_id = *docs.borrow()
			.get(&root_key)
			.unwrap_or(&0);
		ACTIVE_DOCS.with(
			|cell| {
				*cell.borrow_mut() = None;
			}
		);
		Ok(doc_id)
	}
);
