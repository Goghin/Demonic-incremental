
class_name GameState
extends RefCounted


var resources: Dictionary = {}
var generators: Dictionary = {}
var upgrades: Dictionary = {}
var upgrade_groups: Dictionary = {}
var lava_mite_dormancy_penalty: float = 0.0

var eternal_flame_state: EternalFlameState
var realm_configuration: RealmConfiguration
var realm_effects: RealmEffects
var eternal_flame_upgrade_manager: EternalFlameUpgradeManager

var realm_stabilized: bool = true

var heat_leak_threshold: float = 100000.0
var heat_leak_base: float = 1.0
var heat_leak_scaling: float = 16.4
var heat_leak_exponent: float = 2.14

var matter_decay_threshold: float = 10000.0
var matter_decay_base: float = 0.0
var matter_decay_scaling: float = 1
var matter_decay_exponent: float = 2.0






func _init() -> void:
	_initialize_resources()
	_initialize_generators()
	_initialize_upgrade_groups()
	_initialize_upgrades()
	
	eternal_flame_state = EternalFlameState.new()
	eternal_flame_upgrade_manager = EternalFlameUpgradeManager.new()
	realm_configuration = RealmConfiguration.new()
	realm_effects = RealmEffects.new()
	
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
		_create_atomic_friction()
	)
	
	_register_generator(
		_create_molecular_agitation()
	)
	
	_register_generator(
		_create_thermal_furnace()
	)
	
	_register_generator(
		_create_thermal_compressor()
	)
	
	# Ash Management / Lava Mites
	_register_generator(
		_create_lava_mite_colony()
	)
	
	# Matter Furnace
	_register_generator(
		_create_matter_furnace()
	)
	
	_register_generator(
		_create_infernal_forge()
	)


func _create_atomic_friction() -> Generator:
	var definition = GeneratorDefinition.new(
		"atomic_friction",
		"Atomic Friction",
		[],
		[
			GeneratorIO.new(
				ResourceIds.HEAT,
				3.0
			)
		],
		6.0,
		1.22,
		ResourceIds.HEAT,
		false,
		0.0,
		[],
		"res://Generators/Atomic_Friction.png"
	)
	
	var generator = Generator.new(definition)
	generator.level = 1
	generator.unlocked = true
	generator.initial_unlocked = true
	
	return generator


func _create_molecular_agitation() -> Generator:
	var definition = GeneratorDefinition.new(
		"molecular_agitation",
		"Molecular Agitation",
		[],
		[
			GeneratorIO.new(
				ResourceIds.HEAT,
				45.0
			)
		],
		250.0,
		1.22,
		ResourceIds.HEAT,
		false,
		0.0,
		[],
		"res://Generators/Molecular_Agitation.png"
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	generator.initial_unlocked = false
	return generator

func _create_thermal_compressor() -> Generator:
	var definition = GeneratorDefinition.new(
		"thermal_compressor",
		"Thermal Compressor",
		[
			GeneratorIO.new(
				ResourceIds.HEAT,
				45000.0
			)
		],
		[
			GeneratorIO.new(
				ResourceIds.MATTER,
				24.0,
				true
			),
			GeneratorIO.new(
				ResourceIds.ASH,
				8
			)
		],
		2000000.0,
		1.22,
		ResourceIds.HEAT,
		false,
		0.0,
		[],
		"res://Generators/Thermal_Compressor.png"
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	generator.initial_unlocked = false
	return generator

func _create_thermal_furnace() -> Generator:
	var definition = GeneratorDefinition.new(
		"thermal_furnace",
		"Infernal Condensation",
		[
			GeneratorIO.new(
				ResourceIds.HEAT,
				300.0
			)
		],
		[
			GeneratorIO.new(
				ResourceIds.MATTER,
				0.14,
				true
			),
			GeneratorIO.new(
				ResourceIds.ASH,
				0.08
			)
		],
		1000.0,
		1.22,
		ResourceIds.HEAT,
		false,
		0.0,
		[],
		"res://Generators/Thermal_Condensation.png"
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	generator.initial_unlocked = false
	return generator


func _create_lava_mite_colony() -> Generator:
	var definition = GeneratorDefinition.new(
		"lava_mite_colony",
		"Lava Mite Colony",
		[
			GeneratorIO.new(
				ResourceIds.HEAT,
				1000.0
			),
			GeneratorIO.new(
				ResourceIds.MATTER,
				0.15
			),
			GeneratorIO.new(
				ResourceIds.ASH,
				1.2
			)
		],
		[
			GeneratorIO.new(
				ResourceIds.ESSENCE,
				0.0005,
				true,
				false
			)
		],
		150.0,
		1.2,
		ResourceIds.MATTER,
		false,
		0.0,
		[],
		"res://Generators/Lava_Mite_Colony.png"
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	generator.initial_unlocked = false
	return generator


func _create_matter_furnace() -> Generator:
	var definition = GeneratorDefinition.new(
		"matter_furnace",
		"Matter Furnace",
		[
			GeneratorIO.new(
				ResourceIds.MATTER,
				2.5
			)
		],
		[
			GeneratorIO.new(
				ResourceIds.HEAT,
				7500.0
			),
			GeneratorIO.new(
				ResourceIds.ASH,
				1.5
			)
		],
		175.0,
		1.3,
		ResourceIds.MATTER,
		false,
		0.0,
		[],
		"res://Generators/Matter_Furnace.png"
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	generator.initial_unlocked = false
	return generator


func _create_infernal_forge() -> Generator:
	var definition = GeneratorDefinition.new(
		"infernal_forge",
		"Infernal Forge",
		[
			GeneratorIO.new(
				ResourceIds.MATTER,
				4.5
			)
		],
		[
			GeneratorIO.new(
				ResourceIds.ASH,
				5.0
			)
		],
		10000000.0,
		2.0,
		ResourceIds.HEAT,
		true,
		600.0,
		[
			GeneratorIO.new(
				ResourceIds.CRYSTALIZED_FLAME,
				1.0,
				true
			)
		], 
		"res://Generators/Infernal_Forge.png"
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	generator.initial_unlocked = false
	return generator


# -------------------------------------------------------------------
# Upgrade groups
# -------------------------------------------------------------------

func _initialize_upgrade_groups() -> void:
	# Upgrade groups control how upgrades are organized in the UI.
	# They do not make upgrades mutually exclusive.
	
	_register_upgrade_group(
		UpgradeGroupDefinition.new(
			"atomic_friction",
			"Atomic Friction",
			"Develop the fundamental process of generating Heat through atomic friction."
		)
	)
	
	_register_upgrade_group(
		UpgradeGroupDefinition.new(
			"molecular_agitation",
			"Molecular Agitation",
			"Manipulate entire molecules to produce greater amounts of thermal energy."
		)
	)
	
	_register_upgrade_group(
		UpgradeGroupDefinition.new(
			"matter",
			"Matter",
			"Develop the realm's ability to retain, manipulate and exploit Matter."
		)
	)
	
	_register_upgrade_group(
		UpgradeGroupDefinition.new(
			"thermal_furnace",
			"Infernal Condensation",
			"Develop and refine the Infernal Condensation process that converts Heat into Matter."
		)
	)
	
	# Ash Management comes before Matter Furnace because Lava Mites
	# now form the earlier stage of the industrial progression.
	_register_upgrade_group(
		UpgradeGroupDefinition.new(
			"ash_management",
			"Ash Management",
			"Understand and control the consequences of Ash accumulation."
		)
	)
	
	_register_upgrade_group(
		UpgradeGroupDefinition.new(
			"matter_furnace",
			"Matter Furnace",
			"Develop the destruction and conversion of Matter back into thermal energy."
		)
	)
	
	_register_upgrade_group(
		UpgradeGroupDefinition.new(
			"infernal_forge",
			"Infernal Forge",
			"Push Matter through the Infernal Forge and begin the process of crystallization."
		)
	)
	
	_register_upgrade_group(
		UpgradeGroupDefinition.new(
			"thermal_furnace_specialization",
			"Infernal Condensation Specialization",
			"Choose one specialization for Infernal Condensation."
		)
	)


# -------------------------------------------------------------------
# Upgrades
# -------------------------------------------------------------------

func _initialize_upgrades() -> void:
	# Define all upgrades, their requirements and their effects.
	
	# Atomic Friction
	_register_upgrade(
		_create_atomic_friction_optimization()
	)
	
	_register_upgrade(
		_create_atomic_reorganization()
	)
	
	_register_upgrade(
		_create_efficient_atomic_processing()
	)
	
	_register_upgrade(
		_create_atomic_friction_refinement()
	)
	
	# Molecular Agitation
	_register_upgrade(
		_create_molecular_agitation_upgrade()
	)
	
	_register_upgrade(
		_create_molecular_resonance()
	)
	
	_register_upgrade(
		_create_resonant_containment()
	)
	
	_register_upgrade(
		_create_agitation_optimization()
	)
	
	_register_upgrade(
		_create_molecular_agitation_refinement()
	)
	
	# Matter
	_register_upgrade(
		_create_atomic_mastery()
	)
	
	_register_upgrade(
		_create_thermic_mass()
	)
	
	_register_upgrade(
		_create_thermal_compressor_optimization()
	)

	_register_upgrade(
		_create_thermal_compressor_efficiency()
	)

	_register_upgrade(
		_create_high_pressure_compression()
	)

	_register_upgrade(
		_create_thermal_recovery()
	)
	
	# Infernal Condensation
	_register_upgrade(
		_create_thermal_furnace_optimization()
	)
	
	_register_upgrade(
		_create_efficient_thermal_transfer()
	)
	
	_register_upgrade(
		_create_thermal_furnace_refinement()
	)
	
	# Ash Management / Lava Mites
	_register_upgrade(
		_create_ashen_contamination()
	)
	
	_register_upgrade(
		_create_lava_mite_colony_unlock()
	)
	
	_register_upgrade(
		_create_lava_mite_husbandry()
	)
	
	_register_upgrade(
		_create_lava_mite_dormancy()
	)
	
	_register_upgrade(
		_create_lava_mite_refinement()
	)
	
	_register_upgrade(
		_create_lava_mite_adaptation()
	)
	_register_upgrade(
		_create_lava_mite_essence()
	)
	
	_register_upgrade(
		_create_essence_influence()
	)
	# Matter Furnace
	_register_upgrade(
		_create_thermal_conversion()
	)
	
	_register_upgrade(
		_create_matter_refinement()
	)
	
	_register_upgrade(
		_create_matter_furnace_unlock()
	)
	
	_register_upgrade(
		_create_matter_furnace_refinement()
	)
	
	_register_upgrade(
		_create_matter_furnace_ash_reduction()
	)
	# Infernal Forge
	_register_upgrade(
		_create_infernal_forge_unlock()
	)
	
	_register_upgrade(
		_create_infernal_forge_immunity()
	)
	
	_register_upgrade(
		_create_infernal_forge_refinement()
	)
	
	# Infernal Condensation Specialization
	_register_upgrade(
		_create_thermal_ash_filtration()
	)
	
	_register_upgrade(
		_create_thermal_furnace_mastery()
	)
	
	_register_upgrade(
		_create_thermal_furnace_efficiency()
	)
	
	_register_upgrade(
		_create_thermal_purity()
	)


# -------------------------------------------------------------------
# Atomic Friction upgrades
# -------------------------------------------------------------------

func _create_atomic_friction_optimization() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"atomic_friction_optimization",
		"Atomic Friction Optimization",
		"Improves Atomic Friction production by 15% per level.",
		ResourceIds.HEAT,
		200.0,
		[
			UpgradeEffect.modifier(
				"atomic_friction",
				ModifierTypes.PRODUCTION,
				1.15
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"atomic_friction",
				10
			)
		],
		false,
		"",
		"atomic_friction",
		10,
		1.35,
		"atomic_friction"
	)
	
	return Upgrade.new(definition)


func _create_atomic_reorganization() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"atomic_reorganization",
		"Atomic Reorganization",
		"Atomic Friction becomes more powerful per generator level bought.",
		ResourceIds.HEAT,
		125000.0,
		[
			UpgradeEffect.dynamic_generator_modifier(
				"atomic_friction",
				ModifierTypes.PRODUCTION,
				0.05,
				"atomic_friction",
				Modifier.DYNAMIC_GENERATOR_LEVEL
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"atomic_friction",
				35
			)
		],
		false,
		"",
		"atomic_friction",
		1,
		1,
		"atomic_friction"
	)
	
	return Upgrade.new(definition)


func _create_efficient_atomic_processing() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"efficient_atomic_processing",
		"Efficient Atomic Processing",
		"Reduces the cost of Atomic Friction.",
		ResourceIds.HEAT,
		15000.0,
		[
			UpgradeEffect.modifier(
				"atomic_friction",
				ModifierTypes.COST,
				0.2
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"atomic_friction",
				15
			)],
		false,
		"",
		"atomic_friction",
		1,
		1,
		"atomic_friction"
	)
	
	return Upgrade.new(definition)


func _create_atomic_friction_refinement() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"atomic_friction_refinement",
		"Friction Refinement",
		"Refines Atomic Friction, increasing its Heat production by another 15% per level.",
		ResourceIds.HEAT,
		30000.0,
		[
			UpgradeEffect.modifier(
				"atomic_friction",
				ModifierTypes.PRODUCTION,
				1.15
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"atomic_friction",
				25
			)
		],
		false,
		"",
		"atomic_friction",
		5,
		1.85
	)
	
	return Upgrade.new(definition)


# -------------------------------------------------------------------
# Molecular Agitation upgrades
# -------------------------------------------------------------------

func _create_molecular_agitation_upgrade() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"molecular_agitation",
		"Molecular Agitation",
		"Unlocks Manipulation of entire molecules to generate thermal energy.",
		ResourceIds.HEAT,
		1200.0,
		[
			UpgradeEffect.unlock_generator(
				"molecular_agitation"
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"atomic_friction",
				25
			)
		],
		false,
		"",
		"molecular_agitation",
		1,
		1,
		"atomic_friction"
	)
	
	return Upgrade.new(definition)


func _create_molecular_resonance() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"molecular_resonance",
		"Molecular Resonance",
		"Synchronizes molecular movement to amplify thermal output by 15% per level.",
		ResourceIds.HEAT,
		2500.0,
		[
			UpgradeEffect.modifier(
				"molecular_agitation",
				ModifierTypes.PRODUCTION,
				1.15
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"molecular_agitation",
				5
			)
		],
		false,
		"",
		"molecular_agitation",
		10,
		1.45,
		"molecular_agitation"
	)
	
	return Upgrade.new(definition)


func _create_resonant_containment() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"resonant_containment",
		"Resonant Containment",
		"Contains the energy released by Molecular Agitation, massively increasing thermal output.",
		ResourceIds.HEAT,
		650000.0,
		[
			UpgradeEffect.modifier(
				"molecular_agitation",
				ModifierTypes.PRODUCTION,
				2
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"molecular_agitation",
				15
			)
		],
		false,
		"",
		"molecular_agitation",
		1,
		1,
		"molecular_agitation"
	)
	
	return Upgrade.new(definition)


func _create_agitation_optimization() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"agitation_optimization",
		"Agitation Optimization",
		"Reduces the cost scaling of Molecular Agitation.",
		ResourceIds.HEAT,
		1000000.0,
		[
			UpgradeEffect.modifier(
				"molecular_agitation",
				ModifierTypes.COST_SCALING,
				0.98,
				"molecular_agitation"
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"molecular_agitation",
				25
			)
		],
		false,
		"",
		"molecular_agitation",
		3,
		3,
		"molecular_agitation"
	)
	
	return Upgrade.new(definition)


func _create_molecular_agitation_refinement() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"molecular_agitation_refinement",
		"Agitation Refinement",
		"Refines Molecular Agitation, increasing its Heat production by 20% per level.",
		ResourceIds.HEAT,
		300000.0,
		[
			UpgradeEffect.modifier(
				"molecular_agitation",
				ModifierTypes.PRODUCTION,
				1.2
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"molecular_agitation",
				30
			)
		],
		false,
		"",
		"molecular_agitation",
		5,
		1.55,
		"molecular_agitation"
	)
	
	return Upgrade.new(definition)


# -------------------------------------------------------------------
# Matter upgrades
# -------------------------------------------------------------------

func _create_atomic_mastery() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"atomic_mastery",
		"Atomic Mastery",
		"Greatly improves the entire Atomic Friction process. Unlocks Matter generation.",
		ResourceIds.HEAT,
		25000.0,
		[
			UpgradeEffect.modifier(
				"atomic_friction",
				ModifierTypes.PRODUCTION,
				1.5
			),
			UpgradeEffect.modifier(
				"atomic_friction",
				ModifierTypes.COST,
				0.5
			),
			UpgradeEffect.unlock_generator(
				"thermal_furnace"
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"atomic_friction",
				35
			)
		],
		false,
		"",
		"matter",
		1,
		1,
		"atomic_friction"
	)
	
	return Upgrade.new(definition)


func _create_thermic_mass() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"thermic_mass",
		"Thermic Mass",
		"Matter begins to retain and amplify thermal energy.",
		ResourceIds.HEAT,
		0.0,
		[
			UpgradeEffect.dynamic_resource_modifier(
				"",
				ModifierTypes.PRODUCTION,
				0.4,
				ResourceIds.MATTER,
				Modifier.DYNAMIC_RESOURCE_LOG10,
				"thermic_mass",
				ResourceIds.HEAT
			)
		],
		[
			Requirement.new(
				RequirementTypes.RESOURCE,
				ResourceIds.MATTER,
				1.0
			)
		],
		true,
		"",
		"matter"
	)
	
	return Upgrade.new(definition)

func _create_thermal_compressor_optimization() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"thermal_compressor_optimization",
		"Compression Optimization",
		"Improves Thermal Compressor Matter production by 15% per level.",
		ResourceIds.MATTER,
		250.0,
		[
			UpgradeEffect.modifier(
				"thermal_compressor",
				ModifierTypes.PRODUCTION,
				1.15,
				ResourceIds.MATTER
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"thermal_compressor",
				1
			)
		],
		false,
		"",
		"matter",
		10,
		1.35,
		"thermal_compressor"
	)
	
	return Upgrade.new(definition)
	
	
func _create_thermal_compressor_efficiency() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"thermal_compressor_efficiency",
		"Pressure Efficiency",
		"Reduces the Heat required by the Thermal Compressor by 15% per level.",
		ResourceIds.HEAT,
		1500000.0,
		[
			UpgradeEffect.modifier(
				"thermal_compressor",
				ModifierTypes.INPUT_DRAW,
				0.85,
				ResourceIds.HEAT
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"thermal_compressor",
				2
			)
		],
		false,
		"",
		"matter",
		5,
		1.55,
		"thermal_compressor"
	)
	
	return Upgrade.new(definition)
	
func _create_high_pressure_compression() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"high_pressure_compression",
		"High-Pressure Compression",
		"Pushes the Thermal Compressor beyond normal operating pressure, greatly reducing Ash production at the cost of increased Heat consumption.",
		ResourceIds.MATTER,
		2000.0,
		[
			UpgradeEffect.modifier(
				"thermal_compressor",
				ModifierTypes.PRODUCTION,
				0.65,
				ResourceIds.ASH
			),
			UpgradeEffect.modifier(
				"thermal_compressor",
				ModifierTypes.INPUT_DRAW,
				2.60,
				ResourceIds.HEAT
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"thermal_compressor",
				3
			)
		],
		false,
		"thermal_compressor_specialization",
		"matter",
		1,
		1,
		"thermal_compressor"
	)
	
	return Upgrade.new(definition)
	
func _create_thermal_recovery() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"thermal_recovery",
		"Thermal Recovery",
		"Recovers thermal energy normally lost during compression, reducing Heat consumption and cost while providing a modest increase to Matter production.",
		ResourceIds.MATTER,
		1000.0,
		[
			UpgradeEffect.modifier(
				"thermal_compressor",
				ModifierTypes.PRODUCTION,
				1.20,
				ResourceIds.MATTER
			),
			UpgradeEffect.modifier(
				"thermal_compressor",
				ModifierTypes.INPUT_DRAW,
				0.70,
				ResourceIds.HEAT
			),
			UpgradeEffect.modifier(
				"thermal_compressor",
				ModifierTypes.COST,
				.75,
				""
				)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"thermal_compressor",
				1
			)
		],
		false,
		"thermal_compressor_specialization",
		"matter",
		1,
		1,
		"thermal_compressor"
	)
	
	return Upgrade.new(definition)	
	
	
# -------------------------------------------------------------------
# Infernal Condensation upgrades
# -------------------------------------------------------------------

func _create_thermal_furnace_optimization() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"thermal_furnace_optimization",
		"Infernal Condensation Optimization",
		"Improves Infernal Condensation Matter output by 15% per level.",
		ResourceIds.MATTER,
		50.0,
		[
			UpgradeEffect.modifier(
				"thermal_furnace",
				ModifierTypes.PRODUCTION,
				1.15,
				ResourceIds.MATTER
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"thermal_furnace",
				5
			)
		],
		false,
		"",
		"thermal_furnace",
		10,
		1.35,
		"thermal_furnace"
	)
	
	return Upgrade.new(definition)


func _create_efficient_thermal_transfer() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"efficient_thermal_transfer",
		"Efficient Thermal Transfer",
		"Reduces the Heat input required by Infernal Condensation by 35%.",
		ResourceIds.HEAT,
		750000.0,
		[
			UpgradeEffect.modifier(
				"thermal_furnace",
				ModifierTypes.INPUT_DRAW,
				0.65
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"thermal_furnace",
				10
			)
		],
		false,
		"",
		"thermal_furnace",
		1,
		1,
		"thermal_furnace"
	)
	
	return Upgrade.new(definition)


func _create_thermal_furnace_refinement() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"thermal_furnace_refinement",
		"Condensation Refinement",
		"Refines Infernal Condensation, increasing all output by 20% per level.",
		ResourceIds.MATTER,
		350.0,
		[
			UpgradeEffect.modifier(
				"thermal_furnace",
				ModifierTypes.PRODUCTION,
				1.2
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"thermal_furnace",
				15
			)
		],
		false,
		"",
		"thermal_furnace",
		5,
		1.55,
		"thermal_furnace"
	)
	
	return Upgrade.new(definition)


# -------------------------------------------------------------------
# Ash Management / Lava Mite upgrades
# -------------------------------------------------------------------

func _create_ashen_contamination() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"ashen_contamination",
		"Ashen Contamination",
		"Ash begins to coat the realm, interfering with all production.",
		ResourceIds.HEAT,
		0.0,
		[
			UpgradeEffect.dynamic_resource_modifier(
				"",
				ModifierTypes.PRODUCTION,
				0.05,
				ResourceIds.ASH,
				Modifier.DYNAMIC_RESOURCE_SQRT_INVERSE,
				"ashen_contamination"
			)
		],
		[
			Requirement.new(
				RequirementTypes.RESOURCE,
				ResourceIds.ASH,
				100.0
			)
		],
		true,
		"",
		"ash_management"
	)
	
	return Upgrade.new(definition)


func _create_lava_mite_colony_unlock() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"lava_mite_colony_unlock",
		"Lava Mite Colony",
		"Unleashes colonies of lava mites that feed on the Ash contaminating your realm.",
		ResourceIds.MATTER,
		100.0,
		[
			UpgradeEffect.unlock_generator(
				"lava_mite_colony"
			)
		],
		[
			Requirement.new(
				RequirementTypes.RESOURCE,
				ResourceIds.ASH,
				200.0
			)
		],
		false,
		"",
		"ash_management"
	)
	
	return Upgrade.new(definition)


func _create_lava_mite_dormancy() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"lava_mite_dormancy",
		"Natural Dormancy",
		"Lava Mite colonies gradually become dormant when left unattended.",
		ResourceIds.HEAT,
		0.0,
		[
			UpgradeEffect.dynamic_resource_modifier(
				"lava_mite_colony",
				ModifierTypes.INPUT_DRAW,
				1.0,
				ResourceIds.ASH,
				Modifier.DYNAMIC_LAVA_MITE_DORMANCY,
				"lava_mite_dormancy"
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"lava_mite_colony",
				1
			)
		],
		true,
		"",
		"ash_management"
	)
	
	return Upgrade.new(definition)

func _create_lava_mite_husbandry() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"lava_mite_husbandry",
		"Lava Mite Husbandry",
		"Improves colony management, reducing the Matter cost of increasing Lava Mite Colony levels by 10% per level.",
		ResourceIds.HEAT,
		285000.0,
		[
			UpgradeEffect.modifier(
				"lava_mite_colony",
				ModifierTypes.COST,
				0.9,
				""
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"lava_mite_colony",
				3
			)
		],
		false,
		"",
		"ash_management",
		5,
		1.8,
		"lava_mite_colony"
	)
	
	return Upgrade.new(definition)

func _create_lava_mite_refinement() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"lava_mite_refinement",
		"Lava Mite Breeding",
		"Improves the effectiveness of Lava Mite colonies by increasing their Ash consumption by 15% per level.",
		ResourceIds.MATTER,
		300.0,
		[
			UpgradeEffect.modifier(
				"lava_mite_colony",
				ModifierTypes.INPUT_DRAW,
				1.15,
				ResourceIds.ASH
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"lava_mite_colony",
				5
			)
		],
		false,
		"",
		"ash_management",
		5,
		1.55,
		"lava_mite_colony"
	)
	
	return Upgrade.new(definition)


func _create_lava_mite_adaptation() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"lava_mite_adaptation",
		"Lava Mite Adaptation",
		"Lava Mites become increasingly ravenous for Ash at higher Ash levels.",
		ResourceIds.MATTER,
		1500.0,
		[
			UpgradeEffect.dynamic_resource_modifier(
				"lava_mite_colony",
				ModifierTypes.INPUT_DRAW,
				0.20,
				ResourceIds.ASH,
				Modifier.DYNAMIC_RESOURCE_POWER_THRESHOLD,
				"lava_mite_ash_adaptation",
				ResourceIds.ASH,
				250.0,
				0.3
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"lava_mite_colony",
				10
			),
			Requirement.new(
				RequirementTypes.RESOURCE,
				ResourceIds.ASH,
				1000
			)
		],
		false,
		"",
		"ash_management",
		3,
		2.0,
		"lava_mite_colony"
	)
	
	return Upgrade.new(definition)

func _create_lava_mite_essence() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"lava_mite_essence",
		"Essence Extraction",
		"Discover how to extract the valuable Essence produced by Lava Mites.",
		ResourceIds.MATTER,
		5000.0,
		[
			UpgradeEffect.unlock_output(
				"lava_mite_colony",
				ResourceIds.ESSENCE
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"lava_mite_colony",
				10
			)
		],
		false,
		"",
		"ash_management",
		1,
		1,
		"lava_mite_colony",
		EternalFlameState.LAVA_MITE_ESSENCE_TECHNOLOGY_ID
	)

	return Upgrade.new(definition)
	
func _create_essence_influence() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"essence_influence",
		"Essence Influence",
		"Essence intensifies the hunger of Lava Mites while weakening the influence of Crystallization.",
		ResourceIds.ESSENCE,
		0.0,
		[
			UpgradeEffect.dynamic_resource_modifier(
				"lava_mite_colony",
				ModifierTypes.INPUT_DRAW,
				0.01,
				ResourceIds.ESSENCE,
				Modifier.DYNAMIC_RESOURCE_SQRT,
				"essence_lava_mite_ash",
				ResourceIds.ASH
			),
			UpgradeEffect.dynamic_sensitivity(
				"",
				"crystallization",
				0.01,
				ResourceIds.ESSENCE,
				ModifierSensitivity.DYNAMIC_RESOURCE_SQRT_INVERSE
			)
		],
		[
			Requirement.new(
				RequirementTypes.RESOURCE,
				ResourceIds.ESSENCE,
				1.0
			)
		],
		true,
		"",
		"ash_management"
	)
	
	return Upgrade.new(definition)
# -------------------------------------------------------------------
# Matter Furnace upgrades
# -------------------------------------------------------------------

func _create_thermal_conversion() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"thermal_conversion",
		"Thermal Conversion",
		"Improves Matter Furnace conversion by 10% per level, while increasing its Matter consumption by 5% per level.",
		ResourceIds.HEAT,
		1250000.0,
		[
			UpgradeEffect.modifier(
				"matter_furnace",
				ModifierTypes.PRODUCTION,
				1.10
			),
			UpgradeEffect.modifier(
				"matter_furnace",
				ModifierTypes.INPUT_DRAW,
				1.05
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"matter_furnace",
				1
			)
		],
		false,
		"",
		"matter_furnace",
		10,
		1.35,
		"matter_furnace"
	)
	
	return Upgrade.new(definition)


func _create_matter_refinement() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"matter_refinement",
		"Matter Refinement",
		"Refines the matter before combustion, reducing material consumption and improving the efficiency of furnace expansion.",
		ResourceIds.HEAT,
		5000000.0,
		[
			UpgradeEffect.modifier(
				"matter_furnace",
				ModifierTypes.INPUT_DRAW,
				0.80
			),
			UpgradeEffect.modifier(
				"matter_furnace",
				ModifierTypes.COST_SCALING,
				0.95,
				"matter_furnace"
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"matter_furnace",
				5
			)
		],
		false,
		"",
		"matter_furnace",
		1,
		1,
		"matter_furnace"
	)
	
	return Upgrade.new(definition)


func _create_matter_furnace_unlock() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"matter_furnace_unlock",
		"Matter Combustion",
		"Unlocks the Matter Furnace.",
		ResourceIds.MATTER,
		100.0,
		[
			UpgradeEffect.unlock_generator(
				"matter_furnace"
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"thermal_furnace",
				25
			),Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"lava_mite_colony",
				5
			)
		],
		false,
		"",
		"matter_furnace"
	)
	
	return Upgrade.new(definition)


func _create_matter_furnace_refinement() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"matter_furnace_refinement",
		"Combustion Refinement",
		"Refines the Matter Furnace, increasing its heat output by 15% per level.",
		ResourceIds.MATTER,
		150.0,
		[
			UpgradeEffect.modifier(
				"matter_furnace",
				ModifierTypes.PRODUCTION,
				1.15,
				ResourceIds.HEAT
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"matter_furnace",
				10
			)
		],
		false,
		"matter_furnace_specialization",
		"matter_furnace",
		5,
		1.55,
		"matter_furnace"
	)
	
	return Upgrade.new(definition)

func _create_matter_furnace_ash_reduction() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"matter_furnace_ash_reduction",
		"Ash Purification",
		"Refines the combustion process, reducing the Ash produced by the Matter Furnace by 20% per level.",
		ResourceIds.MATTER,
		150.0,
		[
			UpgradeEffect.modifier(
				"matter_furnace",
				ModifierTypes.PRODUCTION,
				0.80,
				ResourceIds.ASH
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"matter_furnace",
				10
			)
		],
		false,
		"matter_furnace_specialization",
		"matter_furnace",
		5,
		1.85,
		"matter_furnace"
	)
	
	return Upgrade.new(definition)
# -------------------------------------------------------------------
# Infernal Forge
# -------------------------------------------------------------------

func _create_infernal_forge_unlock() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"infernal_forge_unlock",
		"Crystallization",
		"Unlocks the Infernal Forge. Each Crystallized Flame makes Heat increasingly difficult to produce.",
		ResourceIds.MATTER,
		5000.0,
		[
			UpgradeEffect.unlock_generator(
				"infernal_forge"
			),
			UpgradeEffect.dynamic_resource_modifier(
				"",
				ModifierTypes.PRODUCTION,
				0.8,
				ResourceIds.CRYSTALIZED_FLAME,
				Modifier.DYNAMIC_RESOURCE_EXPONENT,
				"crystallization",
				ResourceIds.HEAT
			),
			UpgradeEffect.dynamic_resource_modifier(
				"",
				ModifierTypes.PRODUCTION,
				0.8,
				ResourceIds.CRYSTALIZED_FLAME,
				Modifier.DYNAMIC_RESOURCE_EXPONENT,
				"crystallization",
				ResourceIds.MATTER
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"matter_furnace",
				1
	)],
		false,
		"",
		"infernal_forge"
	)
	
	return Upgrade.new(definition)


func _create_infernal_forge_immunity() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"infernal_forge_immunity",
		"Forge Immunity",
		"The Infernal Forge is immune to Ashen Contamination and the effects of Crystallization.",
		ResourceIds.HEAT,
		0.0,
		[
			UpgradeEffect.sensitivity(
				"infernal_forge",
				"ashen_contamination",
				0.0
			),
			UpgradeEffect.sensitivity(
				"infernal_forge",
				"crystallization",
				0.0
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"infernal_forge",
				1
			)
		],
		true,
		"",
		"infernal_forge",
		1,
		1,
		"infernal_forge"
	)
	
	return Upgrade.new(definition)


func _create_infernal_forge_refinement() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"infernal_forge_refinement",
		"Forge Refinement",
		"Refines the Infernal Forge, decreasing the cost to start a cycle.",
		ResourceIds.MATTER,
		50000.0,
		[
			UpgradeEffect.modifier(
				"infernal_forge",
				ModifierTypes.COST,
				0.9
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"infernal_forge",
				1
			)
		],
		false,
		"",
		"infernal_forge",
		5,
		1.65,
		"infernal_forge"
	)
	
	return Upgrade.new(definition)


# -------------------------------------------------------------------
# Infernal Condensation Specialization
# -------------------------------------------------------------------

func _create_thermal_ash_filtration() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"thermal_ash_filtration",
		"Ash Filtration",
		"Filters impurities from Infernal Condensation, reducing the Ash produced during Matter creation.",
		ResourceIds.HEAT,
		750000.0,
		[
			UpgradeEffect.modifier(
				"thermal_furnace",
				ModifierTypes.PRODUCTION,
				0.70,
				ResourceIds.ASH
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"thermal_furnace",
				20.0
			)
		],
		false,
		"",
		"thermal_furnace",
		1,
		1,
		"thermal_furnace"
	)
	
	return Upgrade.new(definition)


func _create_thermal_furnace_mastery() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"thermal_furnace_mastery",
		"Infernal Condensation Mastery",
		"Each level of Infernal Condensation increases the production of all its outputs.",
		ResourceIds.HEAT,
		5000000.0,
		[
			UpgradeEffect.dynamic_generator_modifier(
				"thermal_furnace",
				ModifierTypes.PRODUCTION,
				0.015,
				"thermal_furnace",
				Modifier.DYNAMIC_GENERATOR_LEVEL
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"thermal_furnace",
				30.0
			)
		],
		false,
		"",
		"thermal_furnace",
		1,
		1,
		"thermal_furnace"
	)
	
	return Upgrade.new(definition)


func _create_thermal_furnace_efficiency() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"thermal_furnace_efficiency",
		"Condensation Efficiency",
		"Improves the construction process of Infernal Condensation, lowering cost scaling and increasing resistance to Ashen Contamination.",
		ResourceIds.HEAT,
		7500000.0,
		[
			UpgradeEffect.modifier(
				"thermal_furnace",
				ModifierTypes.COST_SCALING,
				0.98
			),
			UpgradeEffect.sensitivity(
				"thermal_furnace",
				"ashen_contamination",
				0.8
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"thermal_furnace",
				25.0
			)
		],
		false,
		"thermal_furnace_specialization",
		"thermal_furnace_specialization",
		1,
		1,
		"thermal_furnace"
		
	)
	
	return Upgrade.new(definition)


func _create_thermal_purity() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"thermal_purity",
		"Condensation Purity",
		"Reduces Infernal Condensation's sensitivity to Ashen Contamination.",
		ResourceIds.HEAT,
		7500000.0,
		[
			UpgradeEffect.sensitivity(
				"thermal_furnace",
				"ashen_contamination",
				0.4
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"thermal_furnace",
				20
			)
		],
		false,
		"thermal_furnace_specialization",
		"thermal_furnace_specialization",
		1,
		1,
		"thermal_furnace"
	)
	
	return Upgrade.new(definition)


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

func _register_upgrade(
	upgrade: Upgrade
	) -> void:
	
	upgrades[upgrade.definition.id] = upgrade


func get_upgrade(
	upgrade_id: String
	) -> Upgrade:
	
	if not upgrades.has(upgrade_id):
		return null
	
	return upgrades[upgrade_id]


# -------------------------------------------------------------------
# Requirements
# -------------------------------------------------------------------

func requirement_met(
	requirement: Requirement
	) -> bool:
	
	if requirement.type == RequirementTypes.RESOURCE:
		return get_resource_amount(
			requirement.target_id
		) >= requirement.value
	
	if requirement.type == RequirementTypes.GENERATOR_LEVEL:
		var generator = get_generator(
			requirement.target_id
		)
		
		if generator == null:
			return false
		
		return generator.level >= requirement.value
	
	if requirement.type == RequirementTypes.UPGRADE_PURCHASED:
		var upgrade = get_upgrade(
			requirement.target_id
		)
		
		if upgrade == null:
			return false
		
		return upgrade.is_purchased()
	
	if requirement.type == RequirementTypes.UPGRADE_LEVEL:
		var upgrade = get_upgrade(
			requirement.target_id
		)
		
		if upgrade == null:
			return false
		
		return upgrade.level >= requirement.value
	
	return false


func requirements_met(
	requirements: Array[Requirement]
	) -> bool:
	
	for requirement in requirements:
		if not requirement_met(
			requirement
		):
			return false
	
	return true


# -------------------------------------------------------------------
# Upgrade exclusivity
# -------------------------------------------------------------------

func upgrade_exclusivity_available(
	upgrade: Upgrade
	) -> bool:
	
	var group = upgrade.definition.exclusivity_group
	
	# An empty exclusivity group means the upgrade is not exclusive.
	if group == "":
		return true
	
	for other_upgrade in upgrades.values():
		if other_upgrade == upgrade:
			continue
		
		if not other_upgrade.is_purchased():
			continue
		
		if other_upgrade.definition.exclusivity_group != group:
			continue
		
		# Another upgrade has already claimed this exclusivity group.
		return false
	
	return true


func get_exclusive_upgrade(
	upgrade: Upgrade
	) -> Upgrade:
	
	var group = upgrade.definition.exclusivity_group
	
	if group == "":
		return null
	
	for other_upgrade in upgrades.values():
		if other_upgrade == upgrade:
			continue
		
		if not other_upgrade.is_purchased():
			continue
		
		if other_upgrade.definition.exclusivity_group != group:
			continue
		
		return other_upgrade
	
	return null


# -------------------------------------------------------------------
# Upgrade group registration / access
# -------------------------------------------------------------------

func _register_upgrade_group(
	group: UpgradeGroupDefinition
	) -> void:
	
	upgrade_groups[group.id] = group


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
	
	var atomic_friction = get_generator(
		"atomic_friction"
	)
	
	if atomic_friction != null:
		atomic_friction.level = 1
	
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
			for output in lava_mite_colony.definition.outputs:
				if output.resource_id == ResourceIds.ESSENCE:
					output.unlocked = true

func is_upgrade_visible(
	upgrade: Upgrade
	) -> bool:
	
	var has_generator_requirement = false
	
	for requirement in upgrade.definition.requirements:
		if requirement.type != RequirementTypes.GENERATOR_LEVEL:
			continue
		
		has_generator_requirement = true
		
		var generator = get_generator(
			requirement.target_id
		)
		
		if generator == null:
			return false
		
		if not generator.unlocked:
			return false
	
	# Upgrades without generator requirements are visible
	# from the beginning.
	if not has_generator_requirement:
		return true
	
	return true
