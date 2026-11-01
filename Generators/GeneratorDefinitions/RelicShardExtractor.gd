class_name RelicShardExtractor
extends RefCounted


static func create() -> Generator:
	var extraction_mode := GeneratorOperationMode.new(
		"normal",
		"Extraction",
		"Consumes 100 Matter over one minute to extract one Relic Shard. Critical cycles yield bonus shards.",
		1.0,
		1.0,
		10.0,
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
			{"item_id": "relic_shard", "quantity": 1, "scale_with_generator_level": false}
		]
	)

	extraction_mode.completion_critical_chance = 0.05

	var recycle_mode := _make_crafting_mode(
		"recycle_relic",
		"Recycle Relic",
		"Consumes the selected relic and recovers 3 Relic Shards.",
		30.0,
		[{"item_type": "relic", "quantity": 1}],
		[{"item_id": "relic_shard", "quantity": 3, "scale_with_generator_level": false}]
	)
	var combine_mode := _make_crafting_mode(
		"combine_shards",
		"Combine Shards",
		"Combines 10 Relic Shards into one Greater Relic Shard.",
		20.0,
		[{"item_type": "stackable", "item_id": "relic_shard", "quantity": 10}],
		[{"item_id": "greater_relic_shard", "quantity": 1, "scale_with_generator_level": false}]
	)
	var forge_standard_mode := _make_crafting_mode(
		"forge_relic",
		"Forge Relic",
		"Consumes 3 Relic Shards to forge a random standard-tier relic.",
		90.0,
		[{"item_type": "stackable", "item_id": "relic_shard", "quantity": 3}],
		[]
	)
	forge_standard_mode.completion_random_relic_tier = 1
	forge_standard_mode.completion_critical_chance = 0.05
	forge_standard_mode.description = "Consumes 3 Relic Shards to forge a random standard-tier relic. " + str(roundi(forge_standard_mode.completion_critical_chance * 100.0)) + "% critical chance to promote the result."

	var forge_greater_mode := _make_crafting_mode(
		"forge_greater_relic",
		"Forge Greater Relic",
		"Consumes 5 Greater Relic Shards to forge a random higher-tier relic.",
		180.0,
		[{"item_type": "stackable", "item_id": "greater_relic_shard", "quantity": 5}],
		[]
	)
	forge_greater_mode.completion_random_relic_tier = 2
	forge_greater_mode.completion_critical_chance = 0.05
	forge_greater_mode.description = "Consumes 5 Greater Relic Shards to forge a random higher-tier relic. " + str(roundi(forge_greater_mode.completion_critical_chance * 100.0)) + "% critical chance to promote the result."

	# All crafting modes use the same base critical chance; the reward
	# interpretation depends on whether the mode produces items or a relic.
	recycle_mode.completion_critical_chance = 0.05
	combine_mode.completion_critical_chance = 0.05

	var modes: Array[GeneratorOperationMode] = [
		extraction_mode,
		recycle_mode,
		combine_mode,
		forge_standard_mode,
		forge_greater_mode
	]
	var definition := GeneratorDefinition.new(
		"relic_shard_extractor",
		"Relic Shard Extractor",
		1.0,
		1.0,
		ResourceIds.CRYSTALLIZED_FLAME,
		true,
		"res://Generators/GeneratorDefinitions/Relic_Crucible_Idle.png",
		modes
	)

	definition.affected_by_realm_cost_reduction = false

	var generator := Generator.new(definition)
	generator.unlocked = true
	generator.initial_unlocked = true
	return generator


static func _make_crafting_mode(
	mode_id: String,
	mode_name: String,
	mode_description: String,
	cycle_duration: float,
	requirements: Array[Dictionary],
	item_outputs: Array[Dictionary]
) -> GeneratorOperationMode:
	return GeneratorOperationMode.new(
		mode_id,
		mode_name,
		mode_description,
		1.0,
		1.0,
		1.0,
		cycle_duration,
		[],
		[],
		[],
		false,
		item_outputs,
		requirements
	)
