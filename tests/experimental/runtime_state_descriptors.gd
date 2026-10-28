extends RefCounted

# Audited complete instance-field descriptors. Metadata is shared, never live
# gameplay containers. All fields (including configuration) remain captured.
# Schema drift fails closed on first use; script reload is outside scope.
const FIELDS: Dictionary = {
	"TickLog": ["events", "clock"],
	"res://Game/AchievementManager.gd": ["unlocked_achievements", "seen_generator_ids", "highest_crystallized_flame_this_run"],
	"res://Game/GeneratorAutomationManager.gd": ["_state_ref", "automation_states", "_offline_enabled_ids", "_offline_index_dirty"],
	"res://Game/UpgradeAutomationManager.gd": ["_state_ref", "automation_states", "_offline_enabled_ids", "_offline_index_dirty", "exclusive_preferences"],
	"res://Game/eternal_flame_state.gd": ["eternal_flame", "spent_flames", "prestige_count", "total_crystallized_flame", "upgrade_levels", "unlocked_technologies"],
	"res://Game/eternal_flame_upgrade.gd": ["id", "display_name", "description", "effect_type", "effect_per_level", "technology_id", "target_generator_id", "prerequisite_upgrade_id", "prerequisite_level", "prerequisite_generator_id", "prerequisite_generator_level", "automatic_level_prestige_requirements", "automatic_min_prestiges", "automatic_total_eternal_flame_requirement", "level", "max_level", "base_cost", "cost_multiplier"],
	"res://Game/eternal_flame_upgrade_manager.gd": ["upgrades"],
	"res://Game/modifier.gd": ["id", "type", "target_id", "multiplier", "source_upgrade_id", "operation_mode_ids", "dynamic_threshold", "dynamic_exponent", "dynamic", "dynamic_resource_id", "dynamic_formula", "dynamic_generator_id", "dynamic_realm_effect_id", "dynamic_realm_effect_is_divisor"],
	"res://Game/modifiersensitivity.gd": ["modifier_id", "multiplier", "source_upgrade_id", "operation_mode_ids", "dynamic", "dynamic_formula", "dynamic_resource_id"],
	"res://Game/realm_configuration.gd": ["stability", "density", "integrity", "intensity", "resonance", "locked"],
	"res://Game/realm_effects.gd": ["heat_leak_threshold", "matter_decay_threshold", "thermal_mass_multiplier", "matter_production_multiplier", "heat_production_realm_multiplier", "heat_production_upgrade_multiplier", "heat_production_multiplier", "generator_cost_multiplier", "ashen_contamination_multiplier"],
	"res://Game/relic_generation_manager.gd": [],
	"res://Game/relic_manager.gd": ["inventory", "inventory_positions", "machine_slots", "equipped", "_next_instance_number", "generation_manager", "_next_item_instance_number", "_gameplay_rng"],
	"res://Game/requirement.gd": ["type", "target_id", "value"],
	"res://Game/resource_statistics.gd": ["statistics", "total_overflow", "total_matter_decayed"],
	"res://Generators/generator.gd": ["definition", "level", "cycle_critical_chance_snapshot", "modifiers", "_production_modifier_cache", "event_effects", "modifier_sensitivities", "production_progress", "initial_unlocked", "unlocked", "manually_paused", "operating", "is_throttled", "cycle_active", "cycle_progress", "auto_run_cycles", "operation_mode_id"],
	"res://Generators/generator_definition.gd": ["id", "display_name", "base_cost", "cost_multiplier", "cost_resource_id", "cycle_based", "operation_modes", "illustration_path", "starting_level", "scale_rates_with_level", "level_upgrade_enabled", "level_upgrade_resource_id", "level_upgrade_base_cost", "level_upgrade_cost_multiplier", "level_upgrade_max_level", "level_critical_chance_bonus", "level_critical_chance_cap"],
	"res://Generators/generator_io.gd": ["resource_id", "amount_per_second", "discrete", "unlocked", "starts_unlocked"],
	"res://Generators/generator_operation_mode.gd": ["id", "display_name", "description", "production_multiplier", "input_multiplier", "activation_cost_multiplier", "increase_level_on_activation", "cycle_duration", "inputs", "outputs", "completion_outputs", "completion_item_outputs", "completion_random_relic_tier", "completion_critical_chance", "crafting_input_requirements", "initially_unlocked", "unlocked", "is_resource_transfer"],
	"res://Resources/GameResource.gd": ["id", "display_name"],
	"res://Resources/resource_state.gd": ["definition", "amount"],
	"res://Upgrades/UpgradeSystem.gd": ["_state_ref"],
	"res://Upgrades/upgrade.gd": ["definition", "level"],
	"res://Upgrades/upgrade_definition.gd": ["id", "display_name", "description", "cost_resource_id", "cost", "cost_multiplier", "max_level", "effects", "requirements", "automatic", "exclusivity_group", "upgrade_group_id", "generator_id", "technology_id", "discovery_id", "icon_path"],
	"res://Upgrades/upgrade_effect.gd": ["type", "target_id", "modifier_type", "value", "modifier_target_id", "modifier_id", "output_resource_id", "operation_mode_id", "operation_mode_ids", "dynamic_formula", "dynamic_resource_id", "dynamic_generator_id", "dynamic_realm_effect_id", "dynamic_realm_effect_is_divisor", "sensitivity_modifier_id", "sensitivity_multiplier", "dynamic_threshold", "dynamic_exponent", "sensitivity_dynamic_formula", "sensitivity_dynamic_resource_id", "dormancy_parameter", "dormancy_value", "event_trigger", "event_action", "event_id", "event_condition_id", "event_chance", "event_value", "event_resource_id", "event_order", "event_source_upgrade_id"],
	"res://Upgrades/upgrade_group_definition.gd": ["id", "display_name", "description"],
	"res://game_state.gd": ["gameplay_log", "gameplay_rng", "gameplay_interval_produced", "gameplay_interval_consumed", "gameplay_interval_lost", "track_gameplay_interval_statistics", "gameplay_realm_run_index", "resources", "discovered_resources", "resource_thresholds", "generators", "upgrades", "upgrade_groups", "upgrade_system", "resource_statistics", "current_run_statistics", "achievement_manager", "simulation_statistics", "realm_layout_id", "realm_layout", "lava_palette", "eternal_flame_state", "realm_configuration", "realm_effects", "eternal_flame_upgrade_manager", "relic_manager", "generator_automation_manager", "upgrade_automation_manager", "realm_stabilized", "prestige_planning", "last_prestige_report", "lava_mite_dormancy_penalty", "heat_leak_threshold", "heat_leak_scaling", "heat_leak_exponent", "total_overflow_this_prestige", "total_matter_decayed_this_prestige", "overflow_bonus_from_last_realm", "matter_decay_threshold", "matter_decay_scaling", "matter_decay_exponent", "lava_mite_dormancy_delay", "lava_mite_dormancy_duration", "lava_mite_dormancy_max_penalty"],
	"res://simulation/simulation.gd": ["_gameplay_snapshot_elapsed", "_gameplay_was_offline", "_gameplay_snapshot_realm_run_index", "state", "_offline_automatic_upgrades", "_offline_upgrade_count", "_offline_realm_run_index", "profiling_enabled", "profile_totals_usec", "profile_call_counts", "diagnostics_enabled", "diagnostic_time_seconds", "diagnostic_events", "diagnostic_checkpoints", "diagnostic_environmental_checkpoints"],
	"res://tests/experimental/transaction_events.gd": ["events"],
}
static var _validated: Dictionary = {}


static func fields_for(target: Object) -> Array:
	var script: Script = target.get_script()
	var key: String = "TickLog" if script == preload("res://tests/experimental/autobuyer_fixtures.gd").TickLog else script.resource_path
	if not FIELDS.has(key):
		return []
	if _validated.has(script):
		return FIELDS[key]
	var observed: Array = []
	for property: Dictionary in target.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var name: String = property["name"]
		if name == "state" and (target is GeneratorAutomationManager or target is UpgradeAutomationManager or target is UpgradeSystem):
			continue
		observed.append(name)
	if observed != FIELDS[key]:
		return []
	_validated[script] = true
	return FIELDS[key]


static func supports(target: Object) -> bool:
	var script: Script = target.get_script()
	if script == null:
		return false
	var key: String = "TickLog" if script == preload("res://tests/experimental/autobuyer_fixtures.gd").TickLog else script.resource_path
	if not FIELDS.has(key):
		return false
	var fields: Array = fields_for(target)
	return _validated.has(script) and (not fields.is_empty() or FIELDS[key].is_empty())
