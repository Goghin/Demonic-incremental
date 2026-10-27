extends RefCounted

const Existing = preload("res://tests/experimental/adaptive_benchmark.gd")
const SCENARIOS: Dictionary = {"early": "fresh", "stable": "stable",
	"heat_equilibrium": "feedback_equilibrium", "matter_equilibrium": "feedback_matter",
	"feedback": "feedback_stored", "ash": "ash", "essence": "essence",
	"consumers": "feedback_recovery", "automation": "automation", "cycles": "cycles", "idle": "idle"}

static func make_state(scenario: String, variant: String = "normal") -> GameState:
	var state: GameState
	if scenario == "late_feedback":
		state = Existing.make_state("feedback_stored")
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/late_feedback_initial.json"))["numeric"]
		for id in state.resources:
			state.set_resource_amount(id, float(data["resource/" + str(id)]))
		Simulation.new(state).update_automatic_upgrades(true)
		for pair in [["lifetime", state.resource_statistics], ["run", state.current_run_statistics]]:
			var saved: Dictionary = {"_total_overflow": data[pair[0] + "/overflow"], "_total_matter_decayed": data[pair[0] + "/decay"]}
			for id in state.resources:
				saved[id] = {}
				for field in ["total_produced", "total_consumed", "total_lost", "highest_amount"]:
					saved[id][field] = data.get(pair[0] + "/" + str(id) + "/" + field, 0.0)
			pair[1].from_dictionary(saved)
		state.total_overflow_this_prestige = data["reward/overflow"]
		state.total_matter_decayed_this_prestige = data["reward/decay"]
	elif scenario == "mixed":
		state = Existing.make_state("automation")
		state.set_resource_amount(ResourceIds.HEAT, 1e8)
		state.set_resource_amount(ResourceIds.MATTER, 1e5)
		state.set_resource_amount(ResourceIds.ESSENCE, 100.0)
		state.set_resource_amount(ResourceIds.CRYSTALLIZED_FLAME, 2.0)
		for id in UpgradeAutomationManager.AUTOMATABLE_GENERATOR_IDS:
			state.eternal_flame_state.unlock_technology(state.upgrade_automation_manager.get_automation_technology_id(id))
			state.upgrade_automation_manager.set_enabled(id, true)
		state.get_upgrade("infernal_forge_unlock").level = 1
		state.get_upgrade("infernal_forge_critical_chance").level = 1
		var simulation := Simulation.new(state)
		simulation.rebuild_upgrade_effects()
		simulation.buy_generator("infernal_forge", "benchmark")
	elif scenario == "reward_boundary":
		state = Existing.make_state("feedback_stored")
		state.set_resource_amount(ResourceIds.CRYSTALLIZED_FLAME, 1.0)
		state.get_generator("infernal_forge").level = 1
		# Locate the production calculator's next integer boundary; no reward
		# formula or balancing constant is copied into the test model.
		var system := PrestigeSystem.new()
		var target: float = system.calculate_eternal_flame_gain(state) + 1.0
		var low: float = 0.0
		var high: float = 1.0
		for _attempt in range(30):
			state.total_overflow_this_prestige = high
			if system.calculate_eternal_flame_gain(state) >= target:
				break
			high *= 10.0
		for _attempt in range(80):
			var middle: float = (low + high) * 0.5
			state.total_overflow_this_prestige = middle
			if system.calculate_eternal_flame_gain(state) < target:
				low = middle
			else:
				high = middle
		state.total_overflow_this_prestige = maxf(0.0, low - 1.0)
		state.resource_statistics.total_overflow = state.total_overflow_this_prestige
		state.current_run_statistics.total_overflow = state.total_overflow_this_prestige
	else:
		state = Existing.make_state(str(SCENARIOS.get(scenario, scenario)))
	if scenario == "matter_equilibrium":
		var simulation := Simulation.new(state)
		for _tick in range(10000):
			simulation.update(0.1, true)
	if variant != "normal":
		var scale: float = 0.99 if variant == "threshold" else 10.0
		state.set_resource_amount(ResourceIds.HEAT, state.realm_effects.heat_leak_threshold * scale)
		state.set_resource_amount(ResourceIds.MATTER, state.realm_effects.matter_decay_threshold * scale)
	return state
