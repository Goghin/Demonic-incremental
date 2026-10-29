extends RefCounted

# Native inventory-cycle capability. No recipe, generation, reward or RNG
# implementation lives in the packet. RelicManager owns every inventory alias.
const CONTRACT: Dictionary = {
	"reads": ["native mode recipes/rewards", "live inputs/speed", "startup chance snapshot", "native inventory", "manager RNG"],
	"writes": ["native recipe slots/stacks/instance IDs", "inventory insertion", "cycle runtime", "resource statistics", "RNG", "owned signals"],
	"order": "native update_cycle_generator at the original registration position",
	"invalidate": "structural changes only; inventory rewards do not rebuild equipment effects",
	"boundary": "exclusive synchronous public call; external callbacks remain native fallback",
}


static func rejection(state: GameState) -> String:
	var manager: RelicManager = state.relic_manager
	if manager == null or manager.get_script() != preload("res://Game/relic_manager.gd") or manager.generation_manager == null or manager.generation_manager.get_script() != preload("res://Game/relic_generation_manager.gd"):
		return "unsupported_crafting_runtime"
	# Separate native streams are safe: native completion retains their actual
	# identities. A scripted RNG could add unreviewed callbacks/side effects.
	if manager._gameplay_rng == null or manager._gameplay_rng.get_script() != null:
		return "unsupported_crafting_rng"
	return ""


static func mode_rejection(mode: GeneratorOperationMode) -> String:
	# Native recipe/reward dictionaries only read scalar data. Refuse custom
	# objects/callables that could introduce callbacks through conversions.
	for entry: Dictionary in mode.crafting_input_requirements + mode.completion_item_outputs:
		for value: Variant in entry.values():
			if typeof(value) not in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]:
				return "unsupported_crafting_data"
	return ""
