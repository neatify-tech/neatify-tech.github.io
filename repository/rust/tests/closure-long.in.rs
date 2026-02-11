    engine.register_fn(
        "walk",
        move |ctx_call: NativeCallContext, language: &str, rule: FnPtr| -> RhaiResult<INT> {
            let nodes = ctx_walk.walk_postorder(language);
            if nodes.is_empty() {
                return Ok(0);
            }
            let docs: Rc<RefCell<HashMap<NodeKey, INT>>> = Rc::new(RefCell::new(HashMap::new()));
            ACTIVE_DOCS.with(|cell| {
                *cell.borrow_mut() = Some(docs.clone());
            });
            for node in nodes.iter() {
                let mut child_docs = Array::new();
                for child in node.children() {
                    let key = NodeKey::from_node(&child);
                    if let Some(id) = docs.borrow().get(&key) {
                        child_docs.push(Dynamic::from(*id));
                    }
                }
                let doc_id: INT = rule
                    .call_within_context(&ctx_call, (node.clone(), child_docs))
                    .map_err(Box::<EvalAltResult>::from)?;
                let key = NodeKey::from_node(node);
                docs.borrow_mut().insert(key, doc_id);
            }
            let root = nodes.last().unwrap();
            let key = NodeKey::from_node(root);
            let doc_id = *docs.borrow().get(&key).unwrap_or(&0);
            ACTIVE_DOCS.with(|cell| {
                *cell.borrow_mut() = None;
            });
            Ok(doc_id)
        },
    );
