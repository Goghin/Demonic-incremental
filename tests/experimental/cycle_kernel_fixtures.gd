extends RefCounted

const Core = preload("res://tests/experimental/core_fixtures.gd")
const Automation = preload("res://tests/experimental/automation_kernel_fixtures.gd")
const DIAGNOSTICS: Array[String] = ["idle", "manual", "active", "partial", "empty", "exact_boundary", "critical", "auto", "auto_disabled", "paused", "zero_speed", "completion_purchase", "cycle_upgrade", "auto_locked", "level_dependency", "ash_heavy", "completion_heavy", "auto_empty", "auto_unfunded", "auto_paused", "paused_operating", "mode_events", "reward_dependency", "auto_header", "auto_competing"]


static func make_state(label: String) -> GameState:
	if label in ["early", "consumer_50000", "mid", "forge_competing"]:
		return Automation.make_state(label)
	if label == "real_completion":
		var event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/core_event_fixture.json"))
		return Core.from_save(event["before"])
	if label.begins_with("reached_"):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/cycle_progression.json"))
		return Core.from_save(data["snapshots"][label.trim_prefix("reached_")])
	# Controlled numerical/controller/event probes; never reached timing claims.
	var state: GameState = make_state("real_completion")
	for generator: Generator in state.generators.values():
		generator.manually_paused = true
		generator.operating = false
	var forge: Generator = state.get_generator("infernal_forge")
	forge.manually_paused = false
	forge.cycle_progress = forge.get_cycle_duration() - 0.000001
	state.set_resource_amount(ResourceIds.HEAT, 100000000.0)
	state.set_resource_amount(ResourceIds.MATTER, 1000000.0)
	state.set_resource_amount(ResourceIds.ASH, 100.0)
	match label:
		"idle", "manual", "auto_disabled":
			forge.cycle_active = false
			forge.cycle_progress = 0.0
			if label == "manual":
				assert(Simulation.new(state).buy_generator(forge.definition.id, "cycle_diagnostic"))
		"active": forge.cycle_progress = 200.0
		"partial", "empty", "exact_boundary":
			forge.cycle_progress = 100.0
			state.set_resource_amount(ResourceIds.MATTER, 0.01 if label == "partial" else (0.0 if label == "empty" else 0.5))
		"paused": forge.manually_paused = true
		"zero_speed":
			forge.cycle_progress = 100.0
			forge.modifiers.append(Modifier.new(ModifierTypes.CYCLE_SPEED, "", 0.0))
		"critical":
			state.gameplay_rng.seed = 78169
			forge.level = 3
			forge.event_effects = event_effects(0.5, 0.5)
		"auto": enable_auto(state)
		"auto_empty", "auto_unfunded", "auto_paused":
			enable_auto(state)
			forge.cycle_progress = 100.0
			if label == "auto_empty":
				state.set_resource_amount(ResourceIds.MATTER, 0.0)
			elif label == "auto_unfunded":
				forge.cycle_active = false
				state.set_resource_amount(ResourceIds.HEAT, 0.0)
				state.set_resource_amount(ResourceIds.MATTER, 0.0)
			else:
				forge.manually_paused = true
				forge.operating = true
		"paused_operating":
			forge.manually_paused = true
			forge.operating = true
			forge.cycle_progress = 100.0
		"mode_events":
			forge.event_effects = event_effects(0.5, 0.5)
			for effect: UpgradeEffect in forge.event_effects:
				effect.operation_mode_ids = ["fast"]
		"auto_locked":
			forge.cycle_active = false
			forge.auto_run_cycles = true
		"cycle_upgrade":
			forge.cycle_progress = 100.0
			Automation.add_upgrade(state, "cycle_speed_autobuy", "atomic_friction", 1.0, [], [UpgradeEffect.modifier(forge.definition.id, ModifierTypes.CYCLE_SPEED, 2.0)])
			Automation.Buyers.enable(state, "atomic_friction", true)
			state.upgrade_automation_manager.automation_states["atomic_friction"]["remaining_cooldown"] = 0.0
		"completion_purchase", "auto_competing":
			Automation.Buyers.enable(state, "atomic_friction")
			state.set_resource_amount(ResourceIds.MATTER, maxf(1000000.0, 4.0 * state.get_generator("atomic_friction").get_cost(state)))
			state.generator_automation_manager.automation_states["atomic_friction"]["remaining_cooldown"] = 0.0
			state.get_generator("atomic_friction").manually_paused = false
			if label == "auto_competing":
				enable_auto(state)
				Automation.add_upgrade(state, "competing_speed", "atomic_friction", 1.0, [], [UpgradeEffect.modifier(forge.definition.id, ModifierTypes.CYCLE_SPEED, 1.5)])
				Automation.Buyers.enable(state, "atomic_friction", true)
				state.upgrade_automation_manager.automation_states["atomic_friction"]["remaining_cooldown"] = 0.0
			# Completion discards Heat; native Matter decay funds this buyer.
		"auto_header":
			forge.level = 0
			forge.cycle_active = false
			enable_auto(state)
			var automatic: Upgrade = Automation.add_upgrade(state, "after_auto_start", "", 0.0, [Requirement.new(RequirementTypes.GENERATOR_LEVEL, forge.definition.id, 1)], [UpgradeEffect.modifier("atomic_friction", ModifierTypes.PRODUCTION, 1.1, ResourceIds.HEAT)])
			automatic.definition.automatic = true
		"level_dependency", "reward_dependency":
			forge.event_effects = event_effects(0.0, 1.0)
			var source: Generator = state.get_generator("atomic_friction")
			state.generators.erase(source.definition.id)
			state.generators[source.definition.id] = source
			source.manually_paused = false
			var modifier := Modifier.new(ModifierTypes.PRODUCTION, ResourceIds.HEAT, 0.5)
			modifier.dynamic = true
			modifier.dynamic_formula = Modifier.DYNAMIC_GENERATOR_LEVEL if label == "level_dependency" else Modifier.DYNAMIC_RESOURCE_SQRT
			modifier.dynamic_resource_id = ResourceIds.CRYSTALLIZED_FLAME
			modifier.dynamic_generator_id = forge.definition.id
			source.modifiers.append(modifier)
			source.invalidate_production_modifier_cache()
		"ash_heavy": state.set_resource_amount(ResourceIds.ASH, 100000000.0)
		"completion_heavy":
			enable_auto(state)
			forge.operation_mode_id = "fast"
			forge.get_operation_mode().unlocked = true
			forge.cycle_progress = 0.0
			forge.event_effects = event_effects(0.5, 1.0)
			forge.modifiers.append(Modifier.new(ModifierTypes.CYCLE_SPEED, "", 10000.0))
			var source: Generator = state.get_generator("atomic_friction")
			source.level = 100000000
			source.manually_paused = false
			state.realm_effects.heat_leak_threshold = 1e20
			var matter: Generator = state.get_generator("molecular_agitation")
			matter.level = 100
			matter.manually_paused = false
			var condenser: Generator = state.get_generator("thermal_furnace")
			condenser.level = 100
			condenser.manually_paused = false
	return state


static func enable_auto(state: GameState) -> void:
	# Diagnostic technology grant only. Reached fixtures pay the native unlock.
	state.eternal_flame_state.unlock_technology(EternalFlameState.get_cycle_auto_run_technology_id("infernal_forge"))
	state.get_generator("infernal_forge").auto_run_cycles = true


static func event_effects(critical_chance: float, loss_chance: float) -> Array[UpgradeEffect]:
	var critical := UpgradeEffect.new(UpgradeEffectTypes.REGISTER_EVENT_EFFECT, "infernal_forge")
	critical.event_trigger = UpgradeEffectTypes.EVENT_CYCLE_COMPLETED
	critical.event_action = UpgradeEffectTypes.EVENT_ACTION_TRIGGER
	critical.event_id = "forge_critical"
	critical.event_chance = critical_chance
	var reward := UpgradeEffect.new(UpgradeEffectTypes.REGISTER_EVENT_EFFECT, "infernal_forge")
	reward.event_trigger = UpgradeEffectTypes.EVENT_CYCLE_COMPLETED
	reward.event_action = UpgradeEffectTypes.EVENT_ACTION_MULTIPLY_COMPLETION_OUTPUT
	reward.event_condition_id = "forge_critical"
	reward.event_value = 1.0
	var loss := UpgradeEffect.new(UpgradeEffectTypes.REGISTER_EVENT_EFFECT, "infernal_forge")
	loss.event_trigger = UpgradeEffectTypes.EVENT_CYCLE_COMPLETED
	loss.event_action = UpgradeEffectTypes.EVENT_ACTION_DECREASE_GENERATOR_LEVEL
	loss.event_chance = loss_chance
	loss.event_value = 1.0
	return [critical, reward, loss]
