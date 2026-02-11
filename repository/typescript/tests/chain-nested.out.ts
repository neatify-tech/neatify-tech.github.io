const result = client.getVeryLongService()
	.withConfig(builder
		.createLongBuilder()
		.withFirstOption(firstValue)
		.withSecondOption(secondValue)
		.build())
	.withLogger(logger)
	.run();
const output = getExtremelyLongClientFactory()
	.getVeryLongService()
	.withExtraConfigurationOption(extraConfig)
	.withConfig(config)
	.run();
