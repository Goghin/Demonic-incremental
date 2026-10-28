extends RefCounted

const Core = preload("res://tests/experimental/core_fixtures.gd")
const TARGETS: Array[String] = ["heat_zero", "heat_below", "heat_at", "heat_above", "heat_stiff", "matter_below", "matter_at", "matter_above", "matter_strong", "phase_below", "phase_at", "phase_above", "purchased_modifier"]


static func make_state(label: String, prefix: int = 0) -> GameState:
	var state: GameState = Core.make_state(label if label in ["early", "mid", "forge_competing"] else "early")
	state.simulation_statistics = ResourceStatistics.new()
	var simulation := Simulation.new(state)
	for tick: int in range(prefix):
		simulation.update(TimeManager.OFFLINE_MAX_GAME_STEP, true)
	# All edits below are diagnostic unit conditions, not measured reachability
	# fixtures. No definitions, resource formulas or feedback are disabled.
	var heat_threshold: float = state.realm_effects.heat_leak_threshold
	var matter_threshold: float = state.realm_effects.matter_decay_threshold
	match label:
		"heat_zero": state.set_resource_amount(ResourceIds.HEAT, 0.0)
		"heat_below": state.set_resource_amount(ResourceIds.HEAT, heat_threshold - 0.00000001)
		"heat_at": state.set_resource_amount(ResourceIds.HEAT, heat_threshold)
		"heat_above": state.set_resource_amount(ResourceIds.HEAT, heat_threshold + 0.00000001)
		"heat_stiff": state.set_resource_amount(ResourceIds.HEAT, heat_threshold * 10.0)
		"matter_below": state.set_resource_amount(ResourceIds.MATTER, matter_threshold - 0.00000001)
		"matter_at": state.set_resource_amount(ResourceIds.MATTER, matter_threshold)
		"matter_above": state.set_resource_amount(ResourceIds.MATTER, matter_threshold + 0.00000001)
		"matter_strong": state.set_resource_amount(ResourceIds.MATTER, 1.00000001)
		"phase_below", "phase_at", "phase_above":
			for generator: Generator in state.generators.values():
				for output: GeneratorIO in generator.get_active_outputs():
					if output.discrete:
						generator.set_production_progress(output.resource_id, 1.0 - 0.000000000001 if label == "phase_below" else (0.0 if label == "phase_at" else 0.000000000001))
		"purchased_modifier":
			state.set_resource_amount(ResourceIds.HEAT, 100000000.0)
			state.set_resource_amount(ResourceIds.MATTER, 10000.0)
			for upgrade: Upgrade in state.upgrades.values():
				if not upgrade.definition.automatic and simulation.can_buy_upgrade(upgrade.definition.id):
					simulation.buy_upgrade(upgrade.definition.id)
					break
	return state


static func first_output_tick() -> int:
	var state: GameState = make_state("early")
	var simulation := Simulation.new(state)
	var before: float = state.resource_statistics.get_total_produced(ResourceIds.MATTER)
	for tick: int in range(1, 2001):
		simulation.update(TimeManager.OFFLINE_MAX_GAME_STEP, true)
		if state.resource_statistics.get_total_produced(ResourceIds.MATTER) > before:
			return tick
	return -1
