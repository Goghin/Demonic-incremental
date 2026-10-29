extends RefCounted

const Existing = preload("res://tests/experimental/relic_crafting_fixtures.gd")
const Buyers = preload("res://tests/experimental/autobuyer_fixtures.gd")

static func make_state(label: String) -> GameState:
	var source: String = "automation" if label == "diagnostic_multi_buyers" else ("consumer_50000" if label == "diagnostic_high_ash" else label)
	var state: GameState = Existing.make_state(source)
	if label == "diagnostic_multi_buyers":
		# Explicit technology grants: diagnostic, never earned progression.
		for id: String in ["molecular_agitation", "lava_mite_colony"]:
			Buyers.enable(state, id)
			Buyers.enable(state, id, true)
	elif label == "diagnostic_high_ash":
		# Stress only. Original earned consumer save is not modified.
		state.set_resource_amount(ResourceIds.ASH, 1000000.0)
	return state
