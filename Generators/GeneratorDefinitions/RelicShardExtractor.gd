class_name RelicShardExtractor
extends RefCounted


static func create() -> Generator:
	var extraction_mode := GeneratorOperationMode.new(
		"normal",
		"Extraction",
		"Consumes 100 Matter over one minute to extract one Relic Shard.",
		1.0,
		1.0,
		1.0,
		60.0,
		[
			GeneratorIO.new(
				ResourceIds.MATTER,
				100.0 / 60.0
			)
		],
		[],
		[],
		false,
		[
			{"item_id": "relic_shard", "quantity": 1}
		]
	)

	var definition := GeneratorDefinition.new(
		"relic_shard_extractor",
		"Relic Shard Extractor",
		10.0,
		1.0,
		ResourceIds.MATTER,
		true,
		"",
		[extraction_mode]
	)

	var generator := Generator.new(definition)
	generator.unlocked = true
	generator.initial_unlocked = true
	return generator
