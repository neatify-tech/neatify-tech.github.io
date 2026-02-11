thread_local! {
    static ACTIVE_DOCS: RefCell<Option<Rc<RefCell<HashMap<NodeKey, INT>>>>> = RefCell::new(None);
}
