
class_name GameState
extends RefCounted

var resources: Dictionary = {}
var generators: Dictionary = {}
var upgrades: Dictionary = {}
var upgrade_groups: Dictionary = {}

var upgrade_system: UpgradeSystem

var resource_statistics: ResourceStatistics
var current_run_statistics: ResourceStatistics
var simulation_statistics: ResourceStatistics = null

var realm_layout_id: String = "default"
var realm_layout: RealmLayout

var eternal_flame_state: EternalFlameState
var realm_configuration: RealmConfiguration
var realm_effects: RealmEffects
var eternal_flame_upgrade_manager: EternalFlameUpgradeManager

var realm_stabilized: bool = true

var lava_mite_dormancy_penalty: float = 0.0

var heat_leak_threshold: float = 100000.0
var heat_leak_base: float = 1.0
var heat_leak_scaling: float = 16.4
var heat_leak_exponent: float = 2.14

var total_overflow_this_prestige: float = 0.0
var overflow_bonus_from_last_realm: float = 1.0

var matter_decay_threshold: float = 10000.0
var matter_decay_base: float = 0.0
var matter_decay_scaling: float = 1
var matter_decay_exponent: float = 2.0

var lava_mite_dormancy_delay: float = 600.0
var lava_mite_dormancy_duration: float = 13800.0
var lava_mite_dormancy_max_penalty: float = 0.90

func _init() -> void:
	_initialize_resources()
	_initialize_generators()
	upgrade_groups = UpgradeGroupRegistry.create_groups()
	upgrades = UpgradeRegistry.create_upgrades()
		
	resource_statistics = ResourceStatistics.new()
	current_run_statistics = ResourceStatistics.new()
	
	upgrade_system = UpgradeSystem.new(
		self
	)
	
	eternal_flame_state = EternalFlameState.new()
	eternal_flame_upgrade_manager = EternalFlameUpgradeManager.new()
	realm_configuration = RealmConfiguration.new()
	realm_effects = RealmEffects.new()
	
	realm_layout_id = "default"
	realm_layout = RealmLayoutRegistry.create_layout(
		realm_layout_id
	)
	
	realm_effects.rebuild(
		realm_configuration,
		eternal_flame_state,
		eternal_flame_upgrade_manager,
		heat_leak_threshold,
		matter_decay_threshold
	)

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
			ResourceIds.ASH,
			"Ash"
		)
	)
	
	_register_resource(
		GameResource.new(
			ResourceIds.CRYSTALIZED_FLAME,
			"Crystalized Flame"
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
	
	_register_generator(
		InfernalCondensation.create()
	)
	
	_register_generator(
		ThermalCompressor.create()
	)
	
	# Ash Management / Lava Mites
	_register_generator(
		LavaMiteColony.create()
	)
	
	# Matter Furnace
	_register_generator(
		MatterFurnace.create()
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

# -------------------------------------------------------------------
# Heat leakage / Matter decay
# -------------------------------------------------------------------

func get_heat_leak_per_second() -> float:
	var heat = get_resource_amount(
		ResourceIds.HEAT
	)
	
	var effective_threshold = realm_effects.heat_leak_threshold
	
	if heat <= effective_threshold:
		return 0.0
	
	var excess_heat = (
		heat - effective_threshold
	)
	
	var normalized_excess = (
		excess_heat
		/ effective_threshold
	)
	
	return (
		heat_leak_base
		+ heat_leak_scaling
		* pow(
			normalized_excess,
			heat_leak_exponent
		)
	)

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
		/ effective_threshold
	)
	
	return (
		matter_decay_base
		+ matter_decay_scaling
		* pow(
			normalized_excess,
			matter_decay_exponent
		)
	)

# -------------------------------------------------------------------
# Current run reset
# -------------------------------------------------------------------

func reset_current_run() -> void:
	for resource_id in resources:
		set_resource_amount(
			resource_id,
			0.0
		)
	
	for generator in generators.values():
		generator.reset()
	
	for upgrade in upgrades.values():
		upgrade.reset()
	
	lava_mite_dormancy_penalty = 0.0
	
	current_run_statistics.reset()
	
	var atomic_friction = get_generator(
		"atomic_friction"
	)
	
	if atomic_friction != null:
		atomic_friction.level = 1
	overflow_bonus_from_last_realm = next_overflow_bonus()
	total_overflow_this_prestige = 0.0
	
	_apply_permanent_technology_unlocks()

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
	
	realm_effects.rebuild(
		realm_configuration,
		eternal_flame_state,
		eternal_flame_upgrade_manager,
		heat_leak_threshold,
		matter_decay_threshold
	)
	
	return true

func begin_realm_configuration() -> void:
	realm_configuration.reset()
	realm_stabilized = false
	
	realm_effects.rebuild(
		realm_configuration,
		eternal_flame_state,
		eternal_flame_upgrade_manager,
		heat_leak_threshold,
		matter_decay_threshold
	)

func _apply_permanent_technology_unlocks() -> void:
	if eternal_flame_state.is_technology_unlocked(
		EternalFlameState.THERMAL_COMPRESSOR_TECHNOLOGY_ID
	):
		var thermal_compressor = get_generator(
			"thermal_compressor"
		)
		
		if thermal_compressor != null:
			thermal_compressor.unlocked = true
	
	if eternal_flame_state.is_technology_unlocked(
		EternalFlameState.LAVA_MITE_ESSENCE_TECHNOLOGY_ID
	):
		var lava_mite_colony = get_generator(
			"lava_mite_colony"
		)
		
		if lava_mite_colony != null:
			for output in lava_mite_colony.get_active_outputs():
				if output.resource_id == ResourceIds.ESSENCE:
					output.unlocked = true

func get_overflow_bonus() -> float:
	var overflow: float = overflow_bonus_from_last_realm

	if overflow <= 0.0:
		return 1.0

	return overflow

func next_overflow_bonus() -> float:
	var overflow: float = total_overflow_this_prestige

	if overflow <= 0.0:
		return 1.0

	return 1+(0.1 * log(overflow) / log(10.0))

func get_overflow_crystallization_multiplier() -> float:
	var crystallized_flames: float = get_resource_amount(
		ResourceIds.CRYSTALIZED_FLAME
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
