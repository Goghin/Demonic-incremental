extends RefCounted

# Reviewed native cycle capabilities, outside the generalized ordered loop.
# All startup/progress/completion/reward behavior stays in native methods.
const Crafting = preload("res://tests/experimental/exact_flow_crafting.gd")
const CAPABILITIES: Dictionary = {"infernal_forge": false, "relic_shard_extractor": true}
const CONTRACT: Dictionary = {
	"reads": ["live mode/duration", "inputs", "modifiers/sensitivities", "resources", "technology", "RNG"],
	"writes": ["cycle runtime", "own level", "resources/statistics", "RNG", "native inventory/recipe state where reviewed", "owned signals/log"],
	"order": "native update_cycle_generator at registration position, after controller",
	"invalidate": "own level change; resource/phase/completion-only changes stay live",
}


static func rejection(generator: Generator, state: GameState) -> String:
	if not CAPABILITIES.has(generator.definition.id):
		return "unsupported_cycle_contract"
	if state.gameplay_rng == null or state.gameplay_rng.get_script() != null:
		return "unsupported_cycle_rng"
	var inventory_cycle: bool = CAPABILITIES[generator.definition.id]
	if inventory_cycle:
		var crafting_error: String = Crafting.rejection(state)
		if not crafting_error.is_empty():
			return crafting_error
	for mode: GeneratorOperationMode in generator.definition.operation_modes:
		if mode.get_script() != preload("res://Generators/generator_operation_mode.gd") or mode.is_resource_transfer:
			return "unsupported_cycle_mode"
		if inventory_cycle:
			var mode_error: String = Crafting.mode_rejection(mode)
			if not mode_error.is_empty():
				return mode_error
		if not inventory_cycle and (not mode.crafting_input_requirements.is_empty() or not mode.completion_item_outputs.is_empty() or mode.completion_random_relic_tier != 0):
			return "unsupported_cycle_inventory"
		for input: GeneratorIO in mode.inputs:
			if input.get_script() != preload("res://Generators/generator_io.gd") or not state.resources.has(input.resource_id):
				return "unsupported_cycle_input"
		for output: GeneratorIO in mode.outputs + mode.completion_outputs:
			if output.get_script() != preload("res://Generators/generator_io.gd") or not state.resources.has(output.resource_id):
				return "unsupported_cycle_output"
	for effect: UpgradeEffect in generator.event_effects:
		if effect.get_script() != preload("res://Upgrades/upgrade_effect.gd") or effect.event_action not in [UpgradeEffectTypes.EVENT_ACTION_TRIGGER, UpgradeEffectTypes.EVENT_ACTION_MULTIPLY_COMPLETION_OUTPUT, UpgradeEffectTypes.EVENT_ACTION_DECREASE_GENERATOR_LEVEL]:
			return "unsupported_cycle_event"
	return ""
