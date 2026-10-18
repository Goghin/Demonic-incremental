
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
var generator_automation_manager: GeneratorAutomationManager
var upgrade_automation_manager: UpgradeAutomationManager

var realm_stabilized: bool = true

var lava_mite_dormancy_penalty: float = 0.0

var heat_leak_threshold: float = 1000.0
var heat_leak_scaling: float = 30.0
var heat_leak_exponent: float = 2.5

var total_overflow_this_prestige: float = 0.0
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
	
	_register_generator(
		InfernalForge.create()
	)

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

func set_resource_amount(
	resource_id: String,
	amount: float
	) -> void:
	
	if not resources.has(resource_id):
		return
	
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
	# Each realm starts with level 1 of the first line for both resources.
	for upgrade_id in [
		HEAT_THRESHOLD_LINE_1_ID,
		MATTER_THRESHOLD_LINE_1_ID
	]:
		var upgrade: Upgrade = get_upgrade(upgrade_id)
		if upgrade != null:
			upgrade.level = 1
	_refresh_base_thresholds()


func _refresh_base_thresholds() -> void:
	var heat_line_1: Upgrade = get_upgrade(HEAT_THRESHOLD_LINE_1_ID)
	var heat_line_2: Upgrade = get_upgrade(HEAT_THRESHOLD_LINE_2_ID)
	var matter_line_1: Upgrade = get_upgrade(MATTER_THRESHOLD_LINE_1_ID)
	var matter_line_2: Upgrade = get_upgrade(MATTER_THRESHOLD_LINE_2_ID)
	var heat_base: float = 0.0
	if heat_line_1 != null:
		heat_base += float(heat_line_1.level) * 1000.0
	if heat_line_2 != null:
		heat_base += float(heat_line_2.level) * 10000.0
	var matter_base: float = 0.0
	if matter_line_1 != null:
		matter_base += float(matter_line_1.level) * 100.0
	if matter_line_2 != null:
		matter_base += float(matter_line_2.level) * 1000.0
	# Keep base thresholds positive even if every upgrade level is zero.
	heat_leak_threshold = maxf(heat_base, 1.0)
	matter_decay_threshold = maxf(matter_base, 1.0)


func is_threshold_upgrade(upgrade_id: String) -> bool:
	return upgrade_id in [
		HEAT_THRESHOLD_LINE_1_ID,
		HEAT_THRESHOLD_LINE_2_ID,
		MATTER_THRESHOLD_LINE_1_ID,
		MATTER_THRESHOLD_LINE_2_ID
	]


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
	
		
	overflow_bonus_from_last_realm = next_overflow_bonus()
	total_overflow_this_prestige = 0.0
	
	_apply_permanent_technology_unlocks()
	rebuild_realm_effects()

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

func get_overflow_bonus() -> float:
	# Overflow is a bonus, never a penalty. Clamp this as well as the
	# next-run calculation so existing saves with a sub-1 multiplier
	# cannot reduce the first Smash reward to zero.
	return maxf(1.0, overflow_bonus_from_last_realm)

func next_overflow_bonus() -> float:
	var overflow: float = total_overflow_this_prestige

	if overflow <= 0.0:
		return 1.0

	var multiplier: float = 1.0 + (0.1 * log(overflow) / log(10.0))
	return maxf(1.0, multiplier)

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
