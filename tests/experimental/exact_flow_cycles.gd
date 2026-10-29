extends RefCounted

# A reviewed native resource-cycle capability, not a second crafting engine.
# Selection stays outside the generalized ordered loop. Inventory crafting is
# deliberately a separate future contract.
const CONTRACT: Dictionary = {
	"reads": ["live mode/duration", "inputs", "modifiers/sensitivities", "resources", "technology", "RNG"],
	"writes": ["cycle runtime", "own level", "resources/statistics", "RNG", "owned signals/log"],
	"order": "native update_cycle_generator at registration position, after controller",
	"invalidate": "own level change; resource/phase/completion-only changes stay live",
}


static func rejection(generator: Generator, state: GameState) -> String:
	if generator.definition.id != "infernal_forge":
		return "unsupported_cycle_contract"
	if state.gameplay_rng == null or state.gameplay_rng.get_script() != null:
		return "unsupported_cycle_rng"
	for mode: GeneratorOperationMode in generator.definition.operation_modes:
		if mode.get_script() != preload("res://Generators/generator_operation_mode.gd") or mode.is_resource_transfer:
			return "unsupported_cycle_mode"
		if not mode.crafting_input_requirements.is_empty() or not mode.completion_item_outputs.is_empty() or mode.completion_random_relic_tier != 0:
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
