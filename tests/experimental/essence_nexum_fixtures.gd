extends RefCounted

const Cycles = preload("res://tests/experimental/cycle_kernel_fixtures.gd")
const Consumers = preload("res://tests/experimental/consumer_fixtures.gd")
const Core = preload("res://tests/experimental/core_fixtures.gd")
const DIAGNOSTICS: Array[String] = ["essence_only", "essence_feedback", "essence_threshold", "essence_tiny", "essence_large", "compression", "compression_low_ash", "compression_partial", "compression_empty", "compression_exact", "compression_phase", "expansion", "expansion_partial", "nexum_large", "transfer_modifiers", "transfer_no_input", "mixed_resources", "sequential_feedback", "automation_resources", "forge_resources", "feedback_stress"]


static func make_state(label: String) -> GameState:
	if label in ["early", "consumer_50000", "mid", "forge_competing"]:
		return Cycles.make_state(label)
	if label.begins_with("earned_"):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/essence_nexum_progression.json"))
		return Core.from_save(data["snapshots"][label.trim_prefix("earned_")])
	# Controlled diagnostics: explicit grants and stocks, never reached evidence.
	var state: GameState = Cycles.make_state("real_completion") if label == "forge_resources" else Consumers.make_state("consumer_50000")
	state.gameplay_rng.seed = 728134
	for generator: Generator in state.generators.values():
		if label != "forge_resources" or generator.definition.id != "infernal_forge":
			generator.manually_paused = true
			generator.operating = false
	state.eternal_flame_state.unlock_technology(EternalFlameState.LAVA_MITE_ESSENCE_TECHNOLOGY_ID)
	state.eternal_flame_state.unlock_technology(EternalFlameState.THERMAL_COMPRESSOR_TECHNOLOGY_ID)
	for id: String in ["lava_mite_essence", "lava_mite_essence_adaptation", "intensified_friction_essence", "thermal_compressor_unlock"]:
		state.get_upgrade(id).level = 1
	Simulation.new(state).rebuild_upgrade_effects()
	state.set_resource_amount(ResourceIds.HEAT, 1000000.0)
	state.set_resource_amount(ResourceIds.MATTER, 10000.0)
	state.set_resource_amount(ResourceIds.ASH, 1000.0)
	if not label.begins_with("essence_"):
		state.set_resource_amount(ResourceIds.ESSENCE, 200.0)
	state.set_resource_amount(ResourceIds.NEXUM, 0.0 if label.begins_with("compression") else 20.0)
	var source: Generator = state.get_generator("atomic_friction")
	var colony: Generator = state.get_generator("lava_mite_colony")
	var compressor: Generator = state.get_generator("thermal_compressor")
	compressor.level = 2
	if label.begins_with("compression") or label in ["expansion", "expansion_partial", "nexum_large", "transfer_modifiers", "transfer_no_input"]:
		compressor.manually_paused = false
		if label in ["expansion", "expansion_partial", "nexum_large", "transfer_modifiers", "transfer_no_input"]:
			assert(compressor.set_operation_mode("expansion"))
		match label:
			"compression_low_ash":
				state.set_resource_amount(ResourceIds.MATTER, 10000.0)
				state.set_resource_amount(ResourceIds.ASH, 10.0)
				state.set_resource_amount(ResourceIds.ESSENCE, 2000.0)
			"compression_partial": state.set_resource_amount(ResourceIds.ESSENCE, 0.03)
			"compression_empty": state.set_resource_amount(ResourceIds.ESSENCE, 0.0)
			"compression_exact": state.set_resource_amount(ResourceIds.ESSENCE, 20.0)
			"compression_phase": compressor.production_progress[ResourceIds.NEXUM] = 0.999999999999
			"expansion_partial": state.set_resource_amount(ResourceIds.NEXUM, 0.03)
			"nexum_large": state.set_resource_amount(ResourceIds.NEXUM, 1e100)
			"transfer_no_input": compressor.get_operation_mode().inputs.clear()
			"transfer_modifiers":
				compressor.modifiers.append(Modifier.new(ModifierTypes.INPUT_DRAW, "", 73.0))
				compressor.modifiers.append(Modifier.new(ModifierTypes.PRODUCTION, "", 19.0))
		return state
	source.manually_paused = false
	if label in ["essence_only", "essence_threshold", "essence_tiny", "essence_large", "mixed_resources", "sequential_feedback", "feedback_stress"]:
		assert(source.set_operation_mode("intensified_friction"))
		source.level = 10000 if label == "feedback_stress" else 100
	if label.begins_with("essence_"):
		state.set_resource_amount(ResourceIds.ESSENCE, 0.0)
		match label:
			"essence_threshold": state.set_resource_amount(ResourceIds.ESSENCE, 0.999999)
			"essence_tiny": state.set_resource_amount(ResourceIds.ESSENCE, 1e-20)
			"essence_large": state.set_resource_amount(ResourceIds.ESSENCE, 1e100)
	if label in ["essence_feedback", "mixed_resources", "automation_resources", "forge_resources", "feedback_stress"]:
		colony.manually_paused = false
		colony.production_progress[ResourceIds.ESSENCE] = 0.999999
		state.get_generator("molecular_agitation").manually_paused = false
		state.get_generator("thermal_furnace").manually_paused = false
	if label in ["mixed_resources", "forge_resources", "feedback_stress"]:
		compressor.manually_paused = false
	if label == "mixed_resources":
		source.level = 30
		Cycles.Automation.Buyers.enable(state, "atomic_friction")
	if label == "sequential_feedback":
		var consumer: Generator = Consumers.add_machine(state, "ordered_resource_probe", [GeneratorIO.new(ResourceIds.ESSENCE, 2.0), GeneratorIO.new(ResourceIds.NEXUM, 1.0)], [GeneratorIO.new(ResourceIds.HEAT, 5.0), GeneratorIO.new(ResourceIds.ESSENCE, 0.1)])
		var draw := Modifier.new(ModifierTypes.INPUT_DRAW, ResourceIds.NEXUM, 0.5)
		draw.id = "probe_draw"
		draw.dynamic = true
		draw.dynamic_resource_id = ResourceIds.ESSENCE
		draw.dynamic_formula = Modifier.DYNAMIC_RESOURCE_SQRT
		consumer.modifiers.append(draw)
		var feedback := Modifier.new(ModifierTypes.PRODUCTION, ResourceIds.HEAT, 0.2)
		feedback.dynamic = true
		feedback.dynamic_formula = Modifier.DYNAMIC_RESOURCE_LOG10
		feedback.dynamic_resource_id = ResourceIds.ESSENCE
		consumer.modifiers.append(feedback)
		var static_penalty := Modifier.new(ModifierTypes.PRODUCTION, ResourceIds.HEAT, 0.75)
		static_penalty.id = "static_penalty_dynamic_sensitivity"
		consumer.modifiers.append(static_penalty)
		var sensitivity := ModifierSensitivity.new(static_penalty.id, 0.25)
		sensitivity.dynamic = true
		sensitivity.dynamic_resource_id = ResourceIds.ESSENCE
		sensitivity.dynamic_formula = ModifierSensitivity.DYNAMIC_RESOURCE_SQRT_INVERSE
		consumer.modifier_sensitivities.append(sensitivity)
	if label == "automation_resources":
		Cycles.Automation.Buyers.enable(state, "lava_mite_colony", true)
		state.upgrade_automation_manager.automation_states["lava_mite_colony"]["remaining_cooldown"] = 0.0
		Cycles.Automation.Buyers.enable(state, "atomic_friction")
		state.set_resource_amount(ResourceIds.HEAT, source.get_cost(state) * 0.99)
	return state
