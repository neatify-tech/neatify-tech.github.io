   engine.register_fn("setting", move |key: &str, default: Dynamic| -> Dynamic {
       settings_for_get.get(key).cloned().unwrap_or(default)
  });
