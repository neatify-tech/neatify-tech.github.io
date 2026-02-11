config.repositories
	.insert(
		0,
		RepositoryConfig {
			name: name.to_string(),
			path: root.to_string_lossy().to_string(),
			url: url_opt,
			version: None,
			last_checked: None,
			last_synced: None
		}
	);
