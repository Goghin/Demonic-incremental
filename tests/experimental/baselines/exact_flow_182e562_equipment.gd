extends RefCounted

# Read-only native equipment capability. No inventory walk, effect rebuild,
# mutation journal or retained relic dictionaries. Public calls are exclusive.
const TYPES: Array[String] = [ModifierTypes.PRODUCTION, ModifierTypes.INPUT_DRAW, ModifierTypes.CYCLE_SPEED, ModifierTypes.EVENT_CHANCE]
const FORMULAS: Array[String] = [Modifier.DYNAMIC_NONE, Modifier.DYNAMIC_RESOURCE_LOG10, Modifier.DYNAMIC_RESOURCE_SQRT, Modifier.DYNAMIC_RESOURCE_SQRT_INVERSE, Modifier.DYNAMIC_RESOURCE_INVERSE_BOOST, Modifier.DYNAMIC_GENERATOR_LEVEL, Modifier.DYNAMIC_RESOURCE_EXPONENT, Modifier.DYNAMIC_LAVA_MITE_DORMANCY, Modifier.DYNAMIC_RESOURCE_POWER_THRESHOLD]
const CONTRACT: Dictionary = {
	"reads": ["existing native generator modifier/sensitivity arrays", "live resources", "native cycle events"],
	"writes": [],
	"public_boundary": "release every packet; caller performs native equipment/rebuild APIs before reentry",
	"interior_mutations": "no reviewed core path equips, moves, generates or consumes inventory",
	"fallback": ["external callbacks", "active inventory crafting", "recipe-bearing autobuyer", "unknown relic semantics"],
}


static func rejection(state: GameState) -> String:
	var manager: RelicManager = state.relic_manager
	if manager == null or manager.get_script() != preload("res://Game/relic_manager.gd") or manager.generation_manager == null or manager.generation_manager.get_script() != preload("res://Game/relic_generation_manager.gd"):
		return "unknown_equipment_runtime"
	# Native buyers are the only admitted purchase path inside a continuous
	# packet. Passive ingredients must not turn a purchase into inventory work.
	for id: String in GeneratorAutomationManager.AUTOMATABLE_GENERATOR_IDS:
		if not bool(state.generator_automation_manager.automation_states.get(id, {}).get("enabled", false)):
			continue
		var generator: Generator = state.get_generator(id)
		if generator != null:
			for mode: GeneratorOperationMode in generator.definition.operation_modes:
				if not mode.crafting_input_requirements.is_empty():
					return "equipment_inventory_purchase"
	return ""


static func modifier_rejection(modifier: Modifier) -> String:
	if not modifier.id.begins_with("relic:"):
		return ""
	if modifier.type not in TYPES or not is_finite(modifier.multiplier):
		return "unsupported_equipment_effect"
	if modifier.dynamic and modifier.dynamic_formula not in FORMULAS:
		return "unsupported_equipment_formula"
	return ""
