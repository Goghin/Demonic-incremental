extends RefCounted

const Core = preload("res://tests/experimental/core_fixtures.gd")
const Ordered = preload("res://tests/experimental/ordered_flow_fixtures.gd")
const REACHED: Array[String] = ["consumer_9500", "consumer_20000", "consumer_50000"]
const DIAGNOSTIC: Array[String] = ["multi_funded", "multi_partial", "multi_exact", "multi_empty", "multi_tiny", "multi_dynamic", "multi_duplicate", "multi_competing", "multi_replenished", "mite_entry", "mite_recovery", "mite_dormant", "mite_high_ash", "transfer"]


static func make_state(label: String) -> GameState:
	if label in REACHED:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/consumer_progression.json"))
		return Core.from_save(data["snapshots"][label.trim_prefix("consumer_")]["save"])
	if label in ["early", "mid", "forge_competing"]:
		return Ordered.make_state(label)
	var state: GameState = make_state("consumer_20000")
	# Controlled edge cases only, never advertised as progression coverage.
	for generator: Generator in state.generators.values():
		generator.manually_paused = true
		generator.operating = false
	if label.begins_with("mite_"):
		var colony: Generator = state.get_generator("lava_mite_colony")
		colony.manually_paused = false
		state.set_resource_amount(ResourceIds.HEAT, 600.0 if label == "mite_entry" else 100000000.0)
		state.set_resource_amount(ResourceIds.ASH, 10000.0 if label != "mite_high_ash" else 100000000.0)
		colony.is_throttled = label == "mite_recovery"
		if label == "mite_dormant":
			state.set_lava_mite_dormancy_penalty(0.75)
		return state
	state.set_resource_amount(ResourceIds.HEAT, 100.0)
	state.set_resource_amount(ResourceIds.MATTER, 10.0)
	var inputs: Array[GeneratorIO] = [GeneratorIO.new(ResourceIds.HEAT, 10.0), GeneratorIO.new(ResourceIds.MATTER, 2.0)]
	if label == "multi_duplicate":
		inputs[1] = GeneratorIO.new(ResourceIds.HEAT, 20.0)
	var machine: Generator = add_machine(state, "diagnostic_consumer", inputs, [GeneratorIO.new(ResourceIds.HEAT, 0.25), GeneratorIO.new(ResourceIds.ASH, 2.5, true)])
	match label:
		"multi_partial": state.set_resource_amount(ResourceIds.MATTER, 0.03)
		"multi_exact": state.set_resource_amount(ResourceIds.MATTER, 0.2)
		"multi_empty": state.set_resource_amount(ResourceIds.MATTER, 0.0)
		"multi_tiny": state.set_resource_amount(ResourceIds.MATTER, 0.000000000001)
		"multi_duplicate": state.set_resource_amount(ResourceIds.HEAT, 1.5)
		"multi_dynamic":
			var modifier := Modifier.new(ModifierTypes.INPUT_DRAW, ResourceIds.MATTER, 0.75)
			modifier.id = "diagnostic_cross_input"
			modifier.dynamic = true
			modifier.dynamic_resource_id = ResourceIds.HEAT
			modifier.dynamic_formula = Modifier.DYNAMIC_RESOURCE_SQRT
			machine.modifiers.append(modifier)
			var sensitivity := ModifierSensitivity.new(modifier.id, 0.5)
			sensitivity.dynamic = true
			sensitivity.dynamic_resource_id = ResourceIds.HEAT
			sensitivity.dynamic_formula = ModifierSensitivity.DYNAMIC_RESOURCE_SQRT_INVERSE
			machine.modifier_sensitivities.append(sensitivity)
			var feedback := Modifier.new(ModifierTypes.PRODUCTION, ResourceIds.HEAT, 0.125)
			feedback.id = "diagnostic_after_consumption"
			feedback.dynamic = true
			feedback.dynamic_resource_id = ResourceIds.MATTER
			feedback.dynamic_formula = Modifier.DYNAMIC_RESOURCE_LOG10
			machine.modifiers.append(feedback)
		"multi_competing":
			state.set_resource_amount(ResourceIds.MATTER, 0.3)
			add_machine(state, "diagnostic_competitor", inputs.duplicate(), [GeneratorIO.new(ResourceIds.HEAT, 0.5)])
		"multi_replenished":
			state.set_resource_amount(ResourceIds.MATTER, 0.0)
			# Register source before both consumers, preserving dictionary order.
			state.generators.erase(machine.definition.id)
			add_machine(state, "diagnostic_source", [], [GeneratorIO.new(ResourceIds.MATTER, 10.0, true)])
			state.generators[machine.definition.id] = machine
		"transfer": machine.get_operation_mode().is_resource_transfer = true
	return state


static func add_machine(state: GameState, id: String, inputs: Array[GeneratorIO], outputs: Array[GeneratorIO]) -> Generator:
	var mode := GeneratorOperationMode.new("normal", "Diagnostic", "Controlled IO ordering probe", 1.0, 1.0, 1.0, 0.0, inputs, outputs)
	var definition := GeneratorDefinition.new(id, id, 1.0, 1.0, ResourceIds.HEAT, false, "", [mode])
	var generator := Generator.new(definition)
	generator.level = 1
	state.generators[id] = generator
	return generator
