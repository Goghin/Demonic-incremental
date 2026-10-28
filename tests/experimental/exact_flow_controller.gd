extends RefCounted

# Reviewed adapter to the existing synchronous controller. No clock is advanced.
# The only generator-specific capability selection lives here, not in the IO loop.
const CONTRACT: Dictionary = {
	"reads": ["ordered inputs", "input modifiers/sensitivities", "resource balances", "level", "mode", "is_throttled", "lava_mite_dormancy_penalty"],
	"writes": ["is_throttled"],
	"order": "before start checks; before duration; before ordered consumption",
	"external": "TimeManager updates the penalty BETWEEN core calls, never within one",
}


static func needs_native_input_rates(generator: Generator) -> bool:
	return generator.definition.id == "lava_mite_colony"
