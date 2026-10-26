
class_name GameState
extends RefCounted


const HEAT_THRESHOLD_LINE_1_ID: String = "heat_threshold_line_1"
const HEAT_THRESHOLD_LINE_2_ID: String = "heat_threshold_line_2"
const MATTER_THRESHOLD_LINE_1_ID: String = "matter_threshold_line_1"
const MATTER_THRESHOLD_LINE_2_ID: String = "matter_threshold_line_2"


var gameplay_log

# Interval counters used by hidden gameplay-log economy snapshots.
var gameplay_interval_produced: Dictionary = {}
var gameplay_interval_consumed: Dictionary = {}
var gameplay_interval_lost: Dictionary = {}
# Offline catch-up doesn't emit periodic economy snapshots, so avoid maintaining
# interval-only counters while the simulation is running offline.
var track_gameplay_interval_statistics: bool = true
var gameplay_realm_run_index: int = 0

var resources: Dictionary = {}
var discovered_resources: Dictionary = {}
var resource_thresholds: Dictionary = {}
var generators: Dictionary = {}
var upgrades: Dictionary = {}
var upgrade_groups: Dictionary = {}

var upgrade_system: UpgradeSystem

var resource_statistics: ResourceStatistics
var current_run_statistics: ResourceStatistics
var achievement_manager: AchievementManager
var simulation_statistics: ResourceStatistics = null

var realm_layout_id: String = "default"
var realm_layout: RealmLayout

# Stable visual identity for the current realm. Colors are persisted by SaveManager.
var lava_palette: Dictionary = {}

var eternal_flame_state: EternalFlameState
var realm_configuration: RealmConfiguration
var realm_effects: RealmEffects
var eternal_flame_upgrade_manager: EternalFlameUpgradeManager
var relic_manager: RelicManager
var generator_automation_manager: GeneratorAutomationManager
var upgrade_automation_manager: UpgradeAutomationManager

var realm_stabilized: bool = true

# True after Smash until the player explicitly starts the next realm.
var prestige_planning: bool = false
var last_prestige_report: Dictionary = {}

var lava_mite_dormancy_penalty: float = 0.0

var heat_leak_threshold: float = 1000.0
var heat_leak_scaling: float = 30.0
var heat_leak_exponent: float = 2.5

var total_overflow_this_prestige: float = 0.0
var total_matter_decayed_this_prestige: float = 0.0
# Legacy save field retained for compatibility; rewards now use current-realm totals.
var overflow_bonus_from_last_realm: float = 1.0

var matter_decay_threshold: float = 100.0
var matter_decay_scaling: float = 30.0
var matter_decay_exponent: float = 2.5

var lava_mite_dormancy_delay: float = 600.0
var lava_mite_dormancy_duration: float = 13800.0
var lava_mite_dormancy_max_penalty: float = 0.90

func _init() -> void:
	gameplay_log = preload("res://Game/GameplayLog.gd").new()
	_initialize_resources()
	_initialize_generators()
	upgrade_groups = UpgradeGroupRegistry.create_groups()
	upgrades = UpgradeRegistry.create_upgrades()
	_initialize_threshold_upgrades()
		
	resource_statistics = ResourceStatistics.new()
	current_run_statistics = ResourceStatistics.new()
	achievement_manager = AchievementManager.new()
	
	upgrade_system = UpgradeSystem.new(
		self
	)
	
	eternal_flame_state = EternalFlameState.new()
	eternal_flame_upgrade_manager = EternalFlameUpgradeManager.new()
	relic_manager = RelicManager.new()
	
	generator_automation_manager = GeneratorAutomationManager.new(self)
	upgrade_automation_manager = UpgradeAutomationManager.new(self)
	
	realm_configuration = RealmConfiguration.new()
	realm_effects = RealmEffects.new()
	
	realm_layout_id = "default"
	realm_layout = RealmLayoutRegistry.create_layout(
		realm_layout_id
	)
	_generate_lava_palette()
	
	rebuild_realm_effects()

# -------------------------------------------------------------------
# Resources
# -------------------------------------------------------------------

func _initialize_resources() -> void:
	# Define all resources available in the game.
	
	_register_resource(
		GameResource.new(
			ResourceIds.HEAT,
			"Heat"
		)
	)
	
	_register_resource(
		GameResource.new(
			ResourceIds.MATTER,
			"Matter"
		)
	)

	_register_resource(
		GameResource.new(
			ResourceIds.NEXUM,
			"Nexum"
		)
	)
	
	_register_resource(
		GameResource.new(
			ResourceIds.ASH,
			"Ash"
		)
	)
	
	_register_resource(
		GameResource.new(
			ResourceIds.CRYSTALLIZED_FLAME,
			"Crystallized Flame"
		)
	)
	
	_register_resource(
		GameResource.new(
			ResourceIds.ESSENCE,
			"Essence"
		)
	)

# -------------------------------------------------------------------
# Generators
# -------------------------------------------------------------------

func _initialize_generators() -> void:
	# Define all generators and their initial state.
	
	_register_generator(
		AtomicFriction.create()
	)
	
	_register_generator(
		MolecularAgitation.create()	
	)
	
	# Ash Management / Lava Mites
	_register_generator(
		LavaMiteColony.create()
	)
	
	_register_generator(
		InfernalCondensation.create()
	)
	
	# Matter Furnace
	_register_generator(
		MatterFurnace.create()
	)
	
	_register_generator(
		ThermalCompressor.create()
	)
	
	var infernal_forge: Generator = InfernalForge.create()
	for operation_mode in infernal_forge.definition.operation_modes:
		operation_mode.increase_level_on_activation = true
	_register_generator(infernal_forge)

	# Temporary, low-cost cycle generator used to test persistent shard rewards.
	# Its extraction mode advances the level; processing modes do not.
	var relic_crucible: Generator = RelicShardExtractor.create()
	relic_crucible.definition.display_name = "Relic Crucible"
	# Crucible levels are purchased explicitly, independently of its five cycles.
	# Its recipes retain fixed resource costs and item quantities as it levels.
	relic_crucible.definition.starting_level = 1
	# Generator was constructed before this configuration was applied, so sync its runtime level too.
	relic_crucible.level = relic_crucible.definition.starting_level
	relic_crucible.definition.scale_rates_with_level = false
	relic_crucible.definition.level_upgrade_enabled = true
	relic_crucible.definition.level_upgrade_resource_id = ResourceIds.MATTER
	relic_crucible.definition.level_upgrade_base_cost = 100.0
	relic_crucible.definition.level_upgrade_cost_multiplier = 1.25
	relic_crucible.definition.level_upgrade_max_level = 41
	relic_crucible.definition.level_critical_chance_bonus = 0.005
	relic_crucible.definition.level_critical_chance_cap = 0.25
	for operation_mode in relic_crucible.definition.operation_modes:
		operation_mode.increase_level_on_activation = false
	_register_generator(relic_crucible)

# -------------------------------------------------------------------
# Resource registration / access
# -------------------------------------------------------------------

func _register_resource(
	resource: GameResource
	) -> void:
	
	# Create the runtime resource state from the definition.
	resources[resource.id] = ResourceState.new(
		resource
	)

func get_resource_amount(
	resource_id: String
	) -> float:
	
	if not resources.has(resource_id):
		return 0.0
	
	return resources[resource_id].amount

func get_resource_display_name(
	resource_id: String
	) -> String:
	
	if not resources.has(resource_id):
		return ""
	
	return resources[resource_id].definition.display_name

func discover_resource(resource_id: String) -> void:
	if not resources.has(resource_id):
		return
	discovered_resources[resource_id] = true


func is_resource_discovered(resource_id: String) -> bool:
	if resource_id == ResourceIds.HEAT:
		return true
	return bool(discovered_resources.get(resource_id, false))


func get_discovered_resources_save_data() -> Dictionary:
	return discovered_resources.duplicate(true)


func restore_discovered_resources(data: Dictionary) -> void:
	for resource_id in data:
		if not resources.has(str(resource_id)):
			continue
		if bool(data[resource_id]):
			discover_resource(str(resource_id))


func reconcile_resource_discovery() -> void:
	# Recover discoveries from lifetime statistics for saves created before this feature.
	for resource_id in resources:
		if get_resource_amount(resource_id) > 0.0:
			discover_resource(resource_id)
			continue
		if resource_statistics.get_total_produced(resource_id) > 0.0:
			discover_resource(resource_id)
			continue
		if resource_statistics.get_total_consumed(resource_id) > 0.0:
			discover_resource(resource_id)
			continue
		if resource_statistics.get_total_lost(resource_id) > 0.0:
			discover_resource(resource_id)
			continue
		if resource_statistics.get_highest_amount(resource_id) > 0.0:
			discover_resource(resource_id)


func set_resource_amount(
	resource_id: String,
	amount: float
	) -> void:
	
	if not resources.has(resource_id):
		return
	
	if amount > 0.0:
		discover_resource(resource_id)
	
	resources[resource_id].amount = amount
	
	resource_statistics.update_highest(
		resource_id,
		amount
	)
	
	current_run_statistics.update_highest(
		resource_id,
		amount
	)
	
func record_resource_produced(
	resource_id: String,
	amount: float
	) -> void:
	if amount <= 0.0:
		return

	discover_resource(resource_id)

	if track_gameplay_interval_statistics:
		gameplay_interval_produced[resource_id] = (
			float(gameplay_interval_produced.get(resource_id, 0.0))
			+ amount
		)

	resource_statistics.record_produced(
		resource_id,
		amount
	)

	current_run_statistics.record_produced(
		resource_id,
		amount
	)

	if simulation_statistics != null:
		simulation_statistics.record_produced(
			resource_id,
			amount
		)

func record_resource_consumed(
	resource_id: String,
	amount: float
	) -> void:
	if amount <= 0.0:
		return

	discover_resource(resource_id)

	if track_gameplay_interval_statistics:
		gameplay_interval_consumed[resource_id] = (
			float(gameplay_interval_consumed.get(resource_id, 0.0))
			+ amount
		)

	resource_statistics.record_consumed(
		resource_id,
		amount
	)

	current_run_statistics.record_consumed(
		resource_id,
		amount
	)

	if simulation_statistics != null:
		simulation_statistics.record_consumed(
			resource_id,
			amount
		)

func record_resource_lost(
	resource_id: String,
	amount: float
	) -> void:
	if amount <= 0.0:
		return

	discover_resource(resource_id)

	if track_gameplay_interval_statistics:
		gameplay_interval_lost[resource_id] = (
			float(gameplay_interval_lost.get(resource_id, 0.0))
			+ amount
		)

	resource_statistics.record_lost(
		resource_id,
		amount
	)

	current_run_statistics.record_lost(
		resource_id,
		amount
	)

	if simulation_statistics != null:
		simulation_statistics.record_lost(
			resource_id,
			amount
		)

func take_gameplay_interval_statistics() -> Dictionary:
	var result: Dictionary = {
		"produced": gameplay_interval_produced.duplicate(true),
		"consumed": gameplay_interval_consumed.duplicate(true),
		"lost": gameplay_interval_lost.duplicate(true)
	}
	gameplay_interval_produced.clear()
	gameplay_interval_consumed.clear()
	gameplay_interval_lost.clear()
	return result


func get_lava_mite_dormancy_penalty() -> float:
	return lava_mite_dormancy_penalty

func set_lava_mite_dormancy_penalty(
	penalty: float
	) -> void:
	
	lava_mite_dormancy_penalty = clamp(
		penalty,
		0.0,
		0.99
	)

func get_lava_mite_dormancy_multiplier() -> float:
	
	var penalty = lava_mite_dormancy_penalty
	
	return 1.0 - penalty

# -------------------------------------------------------------------
# Generator registration / access
# -------------------------------------------------------------------

func _register_generator(
	generator: Generator
	) -> void:
	
	generators[generator.definition.id] = generator

func get_generator(
	generator_id: String
	) -> Generator:
	
	if not generators.has(generator_id):
		return null
	
	return generators[generator_id]

func get_resources() -> Dictionary:
	return resources

func get_generators() -> Dictionary:
	return generators

# -------------------------------------------------------------------
# Upgrade registration / access
# -------------------------------------------------------------------

func get_upgrade(
	upgrade_id: String
	) -> Upgrade:
	
	if not upgrades.has(upgrade_id):
		return null
	
	return upgrades[upgrade_id]
	
func get_upgrade_group(
	 group_id: String
	 ) -> UpgradeGroupDefinition:
		
	if not upgrade_groups.has(group_id):
		return null 
		
	return upgrade_groups[group_id]


func _initialize_threshold_upgrades() -> void:
	# Apply configured starting levels generically, without resource-specific branches.
	var threshold_definitions: Dictionary = ResourceThresholdRegistry.get_definitions()
	for resource_id in threshold_definitions:
		var threshold_data: Dictionary = threshold_definitions[resource_id]
		var starting_levels: Dictionary = threshold_data.get("starting_levels", {})
		for upgrade_id in starting_levels:
			var upgrade: Upgrade = get_upgrade(str(upgrade_id))
			if upgrade != null:
				upgrade.level = int(starting_levels[upgrade_id])
	_refresh_base_thresholds()


func _refresh_base_thresholds() -> void:
	resource_thresholds.clear()
	var threshold_definitions: Dictionary = ResourceThresholdRegistry.get_definitions()
	for resource_id in threshold_definitions:
		var threshold_data: Dictionary = threshold_definitions[resource_id]
		var threshold: float = float(threshold_data.get("base_threshold", 0.0))
		for upgrade_data in threshold_data.get("upgrades", []):
			var upgrade: Upgrade = get_upgrade(str(upgrade_data["id"]))
			if upgrade != null:
				threshold += float(upgrade.level) * float(upgrade_data["increment"])
		resource_thresholds[resource_id] = maxf(threshold, 1.0)

	# Keep the existing fields consumed by RealmEffects while the underlying
	# threshold calculation is now shared and data-driven.
	heat_leak_threshold = get_resource_threshold(ResourceIds.HEAT)
	matter_decay_threshold = get_resource_threshold(ResourceIds.MATTER)


func get_resource_threshold(
	resource_id: String,
	fallback_threshold: float = 1.0
	) -> float:
	return float(resource_thresholds.get(resource_id, fallback_threshold))


func is_threshold_upgrade(upgrade_id: String) -> bool:
	var threshold_definitions: Dictionary = ResourceThresholdRegistry.get_definitions()
	for resource_id in threshold_definitions:
		var threshold_data: Dictionary = threshold_definitions[resource_id]
		for upgrade_data in threshold_data.get("upgrades", []):
			if str(upgrade_data["id"]) == upgrade_id:
				return true
	return false


func rebuild_realm_effects() -> void:
	_refresh_base_thresholds()
	if realm_effects == null or realm_configuration == null:
		return
	realm_effects.rebuild(
		realm_configuration,
		eternal_flame_state,
		eternal_flame_upgrade_manager,
		heat_leak_threshold,
		matter_decay_threshold
	)


# -------------------------------------------------------------------
# Heat leakage / Matter decay
# -------------------------------------------------------------------

func get_heat_leak_per_second() -> float:
	return get_heat_leak_per_second_at(
		get_resource_amount(ResourceIds.HEAT)
	)


# Calculate the existing leak curve at an arbitrary Heat value without changing
# the live resource balance; the implicit solver uses this during integration.
func get_heat_leak_per_second_at(heat: float) -> float:
	var effective_threshold: float = realm_effects.heat_leak_threshold
	if heat <= effective_threshold:
		return 0.0

	var coefficient: float = maxf(
		20.0,
		heat_leak_scaling - 2.0 * _get_heat_loss_coefficient_upgrade_level()
	)
	var exponent: float = maxf(
		2.0,
		heat_leak_exponent - 0.02 * _get_heat_loss_exponent_upgrade_level()
	)
	return get_heat_leak_per_second_at_with_parameters(
		heat,
		effective_threshold,
		coefficient,
		exponent
	)


# The integrator reuses these parameters throughout one simulation step, avoiding
# repeated upgrade lookups for every numerical solver evaluation.
func get_heat_leak_per_second_at_with_parameters(
	heat: float,
	effective_threshold: float,
	coefficient: float,
	exponent: float
	) -> float:
	if heat <= effective_threshold:
		return 0.0

	var excess_heat: float = heat - effective_threshold
	var normalized_excess: float = excess_heat / maxf(effective_threshold, 1.0)
	return coefficient * pow(normalized_excess, exponent)


func get_matter_decay_per_second() -> float:
	var matter = get_resource_amount(
		ResourceIds.MATTER
	)
	
	var effective_threshold = (
		realm_effects.matter_decay_threshold
	)
	
	if matter <= effective_threshold:
		return 0.0
	
	var excess_matter = (
		matter - effective_threshold
	)
	
	var normalized_excess = (
		excess_matter
		/ maxf(effective_threshold, 1.0)
	)
	
	var coefficient: float = maxf(
		20.0,
		matter_decay_scaling - 2.0 * _get_loss_coefficient_upgrade_level()
	)
	var exponent: float = maxf(
		2.0,
		matter_decay_exponent - 0.02 * _get_loss_exponent_upgrade_level()
	)
	return coefficient * pow(normalized_excess, exponent)



func _get_heat_loss_coefficient_upgrade_level() -> int:
	var upgrade: Upgrade = get_upgrade("heat_loss_coefficient_refinement")
	return upgrade.level if upgrade != null else 0


func _get_heat_loss_exponent_upgrade_level() -> int:
	var upgrade: Upgrade = get_upgrade("heat_loss_exponent_refinement")
	return upgrade.level if upgrade != null else 0


func _get_loss_coefficient_upgrade_level() -> int:
	var upgrade: Upgrade = get_upgrade("loss_coefficient_refinement")
	return upgrade.level if upgrade != null else 0


func _get_loss_exponent_upgrade_level() -> int:
	var upgrade: Upgrade = get_upgrade("loss_exponent_refinement")
	return upgrade.level if upgrade != null else 0

# -------------------------------------------------------------------
# Current run reset
# -------------------------------------------------------------------

func _generate_lava_palette() -> void:
	# Favor crimson and ember-orange realms. Golden-yellow palettes remain
	# possible, but are less common than the redder variations.
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var hue_roll: float = rng.randf()
	var hue: float = lerpf(
		0.002,
		0.105,
		pow(hue_roll, 1.6)
	)
	var dark_hue_shift: float = rng.randf_range(-0.016, 0.006)
	var red_hue_shift: float = rng.randf_range(-0.008, 0.012)
	var saturation: float = rng.randf_range(0.86, 1.0)
	var yellow_bias: float = rng.randf_range(0.0, 1.0)

	lava_palette = {
		"dark": Color.from_hsv(
			fposmod(hue + dark_hue_shift, 1.0),
			rng.randf_range(0.88, 1.0),
			rng.randf_range(0.16, 0.29)
		),
		"red": Color.from_hsv(
			fposmod(hue + red_hue_shift, 1.0),
			saturation,
			rng.randf_range(0.44, 0.64)
		),
		"orange": Color.from_hsv(
			fposmod(hue + 0.010, 1.0),
			rng.randf_range(0.88, 1.0),
			rng.randf_range(0.76, 0.90)
		),
		"bright": Color.from_hsv(
			fposmod(hue + 0.022 + yellow_bias * 0.008, 1.0),
			rng.randf_range(0.68, 0.92),
			1.0
		),
		"glow": Color.from_hsv(
			fposmod(hue + 0.016 + yellow_bias * 0.010, 1.0),
			rng.randf_range(0.76, 0.96),
			1.0
		)
	}

func set_lava_palette_from_save_data(data: Dictionary) -> void:
	var fallback_palette: Dictionary = lava_palette.duplicate(true)
	var restored_palette: Dictionary = {}
	for color_name in ["dark", "red", "orange", "bright", "glow"]:
		if not data.has(color_name):
			lava_palette = fallback_palette
			return
		restored_palette[color_name] = Color(str(data[color_name]))
	lava_palette = restored_palette


func get_lava_palette_save_data() -> Dictionary:
	var result: Dictionary = {}
	for color_name in lava_palette:
		result[color_name] = lava_palette[color_name].to_html(false)
	return result


func reset_current_run() -> void:
	gameplay_realm_run_index += 1
	gameplay_interval_produced.clear()
	gameplay_interval_consumed.clear()
	gameplay_interval_lost.clear()

	for resource_id in resources:
		set_resource_amount(
			resource_id,
			0.0
		)
	
	for generator in generators.values():
		generator.reset()
	
	for upgrade in upgrades.values():
		upgrade.reset()
	_initialize_threshold_upgrades()
	
	lava_mite_dormancy_penalty = 0.0
	
	generator_automation_manager.reset_for_new_run()
	upgrade_automation_manager.reset_for_new_run()
	
	current_run_statistics.reset()
	achievement_manager.reset_current_run_tracking()
	_apply_permanent_starting_generator_levels()
	rebuild_relic_modifiers()
	
		
	total_overflow_this_prestige = 0.0
	total_matter_decayed_this_prestige = 0.0
	
	_apply_permanent_technology_unlocks()
	rebuild_realm_effects()

func rebuild_relic_modifiers() -> void:
	if relic_manager == null:
		return
	for generator in generators.values():
		for modifier in generator.modifiers.duplicate():
			if modifier.id.begins_with("relic:"):
				generator.modifiers.erase(modifier)
		for sensitivity in generator.modifier_sensitivities.duplicate():
			if str(sensitivity.source_upgrade_id).begins_with("relic:"):
				generator.modifier_sensitivities.erase(sensitivity)
		generator.invalidate_production_modifier_cache()

	for generator_id_variant in relic_manager.equipped.keys():
		var generator_id := str(generator_id_variant)
		var generator: Generator = get_generator(generator_id)
		if generator == null:
			continue
		var unlocked_slots: int = eternal_flame_upgrade_manager.get_relic_slot_count(
			generator_id,
			eternal_flame_state
		)
		for slot_index in range(unlocked_slots):
			var instance_id := relic_manager.get_equipped_relic_id(generator_id, slot_index)
			if instance_id == "":
				continue
			var relic: Dictionary = relic_manager.get_relic(instance_id)
			if relic.is_empty():
				continue
			var definition: Dictionary = relic_manager.get_relic_definition(relic)
			if definition.is_empty():
				continue

			var primary_stat: Dictionary = definition.duplicate(true)
			primary_stat["rolled_value"] = relic_manager.get_relic_modifier_value(relic)
			_apply_relic_stat(generator, instance_id, primary_stat)
			var secondary_stat: Variant = relic.get("secondary_stat", {})
			if secondary_stat is Dictionary and not secondary_stat.is_empty():
				_apply_relic_stat(generator, instance_id + ":secondary", secondary_stat)
			var additional_stats: Variant = relic.get("additional_secondary_stats", [])
			if additional_stats is Array:
				for stat_index in range(additional_stats.size()):
					var additional_stat: Variant = additional_stats[stat_index]
					if additional_stat is Dictionary and not additional_stat.is_empty():
						_apply_relic_stat(generator, instance_id + ":secondary:%d" % stat_index, additional_stat)
			generator.invalidate_production_modifier_cache()


func _apply_relic_stat(generator: Generator, relic_source_id: String, stat: Dictionary) -> void:
	var source_id := "relic:" + relic_source_id
	var stat_type := str(stat.get("stat_type", "modifier"))
	var value := float(stat.get("rolled_value", stat.get("multiplier", 1.0)))
	if stat_type == "sensitivity":
		var sensitivity_targets: Variant = stat.get("sensitivity_targets", [])
		if not sensitivity_targets is Array:
			return
		if sensitivity_targets.has("*"):
			# Apply to registered modifier sensitivities only. This keeps the
			# effect universal without changing ordinary modifiers or allowing
			# relics to recursively modify one another.
			var supported_targets: Dictionary = {}
			for existing_sensitivity in generator.modifier_sensitivities:
				if str(existing_sensitivity.source_upgrade_id).begins_with("relic:"):
					continue
				supported_targets[str(existing_sensitivity.modifier_id)] = true
			for target_id in supported_targets.keys():
				generator.modifier_sensitivities.append(
					ModifierSensitivity.new(str(target_id), value, source_id)
				)
		else:
			for target_variant in sensitivity_targets:
				var sensitivity := ModifierSensitivity.new(str(target_variant), value, source_id)
				generator.modifier_sensitivities.append(sensitivity)
		return
	var modifier_type := str(stat.get("modifier_type", ""))
	if modifier_type == "":
		match str(stat.get("family", "")):
			"production":
				modifier_type = ModifierTypes.PRODUCTION
			"cycle_speed":
				modifier_type = ModifierTypes.CYCLE_SPEED
			"input_efficiency":
				modifier_type = ModifierTypes.INPUT_DRAW
	if modifier_type == "":
		return
	var modifier := Modifier.new(modifier_type, str(stat.get("target_id", "")), value)
	modifier.id = source_id
	modifier.source_upgrade_id = source_id
	modifier.dynamic = bool(stat.get("dynamic", false))
	modifier.dynamic_formula = str(stat.get("dynamic_formula", ""))
	modifier.dynamic_resource_id = str(stat.get("dynamic_resource_id", ""))
	modifier.dynamic_generator_id = str(stat.get("dynamic_generator_id", ""))
	modifier.dynamic_threshold = float(stat.get("dynamic_threshold", 1000.0))
	modifier.dynamic_exponent = float(stat.get("dynamic_exponent", 0.35))
	modifier.dynamic_realm_effect_id = str(stat.get("dynamic_realm_effect_id", ""))
	modifier.dynamic_realm_effect_is_divisor = bool(stat.get("dynamic_realm_effect_is_divisor", false))
	var mode_ids: Variant = stat.get("operation_mode_ids", [])
	if mode_ids is Array:
		for mode_id_variant in mode_ids:
			modifier.operation_mode_ids.append(str(mode_id_variant))
	generator.modifiers.append(modifier)


func get_unassigned_eternal_flames() -> int:
	return eternal_flame_state.get_unassigned_flames(
		realm_configuration
	)

func get_assigned_eternal_flames() -> int:
	return realm_configuration.get_assigned_flames()


func get_spent_eternal_flames() -> int:
	return int(
		eternal_flame_state.spent_flames
	)

func stabilize_realm() -> bool:
	if realm_stabilized:
		return false
	
	realm_configuration.lock()
	realm_stabilized = true
	
	rebuild_realm_effects()
	gameplay_log.record_event(
		"realm",
		"realm_stabilized",
		{"assigned_eternal_flames": get_assigned_eternal_flames()}
	)
	
	return true

func begin_realm_configuration() -> void:
	realm_configuration.reset()
	realm_stabilized = false
	
	rebuild_realm_effects()

func _apply_permanent_technology_unlocks() -> void:
	if eternal_flame_state.is_technology_unlocked(
		EternalFlameState.THERMAL_COMPRESSOR_TECHNOLOGY_ID
	):
		var thermal_compressor = get_generator(
			"thermal_compressor"
		)
		
		if thermal_compressor != null:
			thermal_compressor.unlocked = false
	#
	#if eternal_flame_state.is_technology_unlocked(
		#EternalFlameState.LAVA_MITE_ESSENCE_TECHNOLOGY_ID
	#):
		#var lava_mite_colony = get_generator(
			#"lava_mite_colony"
		#)
		#
		#if lava_mite_colony != null:
			#for output in lava_mite_colony.get_active_outputs():
				#if output.resource_id == ResourceIds.ESSENCE:
					#output.unlocked = true

func get_heat_overflow_bonus() -> float:
	return _get_logarithmic_reward_bonus(total_overflow_this_prestige)


func get_matter_decay_bonus() -> float:
	return _get_logarithmic_reward_bonus(total_matter_decayed_this_prestige)


func get_combined_environmental_reward_multiplier() -> float:
	return get_heat_overflow_bonus() * get_matter_decay_bonus()


func _get_logarithmic_reward_bonus(amount: float) -> float:
	if amount <= 0.0:
		return 1.0
	return maxf(1.0, 1.0 + 0.1 * log(amount) / log(10.0))

func get_overflow_crystallization_multiplier() -> float:
	var crystallized_flames: float = get_resource_amount(
		ResourceIds.CRYSTALLIZED_FLAME
	)

	return pow(1.25, crystallized_flames)

func get_lava_mite_dormancy_delay() -> float:
	return lava_mite_dormancy_delay


func get_lava_mite_dormancy_duration() -> float:
	return lava_mite_dormancy_duration


func get_lava_mite_dormancy_max_penalty() -> float:
	return lava_mite_dormancy_max_penalty

func reset_lava_mite_dormancy_parameters() -> void:
	lava_mite_dormancy_delay = 600.0
	lava_mite_dormancy_duration = 13800.0
	lava_mite_dormancy_max_penalty = 0.90

func _apply_permanent_starting_generator_levels() -> void:
	# Atomic Friction always starts at level 1.
	var atomic_friction = get_generator("atomic_friction")

	if atomic_friction != null:
		atomic_friction.level = 1

	# Apply permanent starting-level upgrades.
	for upgrade in eternal_flame_upgrade_manager.upgrades.values():
		if upgrade.effect_type != EternalFlameUpgrade.EFFECT_STARTING_GENERATOR_LEVEL:
			continue

		var upgrade_level: int = (
			eternal_flame_state.get_upgrade_level(
				upgrade.id
			)
		)

		if upgrade_level <= 0:
			continue

		var generator = get_generator(
			upgrade.target_generator_id
		)

		if generator == null:
			continue

		generator.level = int(
			upgrade.effect_per_level * upgrade_level
		)
