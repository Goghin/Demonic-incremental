
class_name GameState
extends RefCounted


var resources: Dictionary = {}
var generators: Dictionary = {}
var upgrades: Dictionary = {}
var upgrade_groups: Dictionary = {}
var lava_mite_dormancy_penalty: float = 0.0


var heat_leak_threshold: float = 100000.0
var heat_leak_base: float = 1.0
var heat_leak_scaling: float = 16.4
var heat_leak_exponent: float = 2.14


func _init() -> void:
	_initialize_resources()
	_initialize_generators()
	_initialize_upgrade_groups()
	_initialize_upgrades()


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
		_create_matter_furnace()
	)
	
	_register_generator(
		_create_lava_mite_colony()
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
		1.21,
		ResourceIds.HEAT
	)
	
	return Generator.new(definition)


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
		1.23,
		ResourceIds.HEAT
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	
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
				0.07
			)
		],
		1000.0,
		1.1,
		ResourceIds.HEAT
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	
	return generator


func _create_matter_furnace() -> Generator:
	var definition = GeneratorDefinition.new(
		"matter_furnace",
		"Matter Furnace",
		[
			GeneratorIO.new(
				ResourceIds.MATTER,
				0.5
			)
		],
		[
			GeneratorIO.new(
				ResourceIds.HEAT,
				2500.0
			),
			GeneratorIO.new(
				ResourceIds.ASH,
				1.2
			)
		],
		125.0,
		1.3,
		ResourceIds.MATTER
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	
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
		[],
		150.0,
		1.2,
		ResourceIds.MATTER
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	
	return generator


func _create_infernal_forge() -> Generator:
	var definition = GeneratorDefinition.new(
		"infernal_forge",
		"Infernal Forge",
		[
			GeneratorIO.new(
				ResourceIds.MATTER,
				1.5
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
		]
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	
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
	
	_register_upgrade_group(
		UpgradeGroupDefinition.new(
			"matter_furnace",
			"Matter Furnace",
			"Develop the destruction and conversion of Matter back into thermal energy."
		)
	)
	
	_register_upgrade_group(
		UpgradeGroupDefinition.new(
			"ash_management",
			"Ash Management",
			"Understand and control the consequences of Ash accumulation."
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
	
	# Matter
	_register_upgrade(
		_create_atomic_mastery()
	)
	
	_register_upgrade(
		_create_thermic_mass()
	)
	
	# Infernal Condensation
	_register_upgrade(
		_create_thermal_furnace_optimization()
	)
	
	_register_upgrade(
		_create_efficient_thermal_transfer()
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
	
	# Ash Management
	_register_upgrade(
		_create_ashen_contamination()
	)
	
	_register_upgrade(
		_create_lava_mite_colony_unlock()
	)
	
	_register_upgrade(_create_lava_mite_dormancy())
	
	# Infernal Forge
	_register_upgrade(
		_create_infernal_forge_unlock()
	)
	
	_register_upgrade(
		_create_infernal_forge_immunity()
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
		1.35
	)
	
	return Upgrade.new(definition)


func _create_atomic_reorganization() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"atomic_reorganization",
		"Atomic Reorganization",
		"Improves Atomic Friction production.",
		ResourceIds.HEAT,
		1250.0,
		[
			UpgradeEffect.dynamic_generator_modifier(
				"atomic_friction",
				ModifierTypes.PRODUCTION,
				0.05,
				"atomic_friction",
				Modifier.DYNAMIC_GENERATOR_LEVEL
			)
		],
		[],
		false,
		"",
		"atomic_friction"
	)
	
	return Upgrade.new(definition)


func _create_efficient_atomic_processing() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"efficient_atomic_processing",
		"Efficient Atomic Processing",
		"Reduces the cost of Atomic Friction.",
		ResourceIds.HEAT,
		1800.0,
		[
			UpgradeEffect.modifier(
				"atomic_friction",
				ModifierTypes.COST,
				0.2
			)
		],
		[],
		false,
		"",
		"atomic_friction"
	)
	
	return Upgrade.new(definition)


# -------------------------------------------------------------------
# Molecular Agitation upgrades
# -------------------------------------------------------------------

func _create_molecular_agitation_upgrade() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"molecular_agitation",
		"Molecular Agitation",
		"Manipulates entire molecules to generate thermal energy.",
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
		"molecular_agitation"
	)
	
	return Upgrade.new(definition)


func _create_molecular_resonance() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"molecular_resonance",
		"Molecular Resonance",
		"Synchronizes molecular movement to amplify thermal output by 15% per level.",
		ResourceIds.HEAT,
		2000.0,
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
		1.35
	)
	
	return Upgrade.new(definition)


func _create_resonant_containment() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"resonant_containment",
		"Resonant Containment",
		"Contains the energy released by Molecular Agitation, increasing thermal output.",
		ResourceIds.HEAT,
		6500.0,
		[
			UpgradeEffect.modifier(
				"molecular_agitation",
				ModifierTypes.PRODUCTION,
				1.80
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
		"molecular_agitation"
	)
	
	return Upgrade.new(definition)


func _create_agitation_optimization() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"agitation_optimization",
		"Agitation Optimization",
		"Reduces the cost scaling of Molecular Agitation.",
		ResourceIds.HEAT,
		10000.0,
		[
			UpgradeEffect.modifier(
				"molecular_agitation",
				ModifierTypes.COST_SCALING,
				0.95,
				"molecular_agitation"
			)
		],
		[
			Requirement.new(
				RequirementTypes.GENERATOR_LEVEL,
				"molecular_agitation",
				20
			)
		],
		false,
		"",
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
		"Greatly improves the entire Atomic Friction process. Unlocks Matter.",
		ResourceIds.HEAT,
		15000.0,
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
				50
			)
		],
		false,
		"",
		"matter"
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
				0.3,
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


# -------------------------------------------------------------------
# Infernal Condensation upgrades
# -------------------------------------------------------------------

func _create_thermal_furnace_optimization() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"thermal_furnace_optimization",
		"Infernal Condensation Optimization",
		"Improves Infernal Condensation output by 15% per level.",
		ResourceIds.MATTER,
		50.0,
		[
			UpgradeEffect.modifier(
				"thermal_furnace",
				ModifierTypes.PRODUCTION,
				1.15
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
		1.35
	)
	
	return Upgrade.new(definition)


func _create_efficient_thermal_transfer() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"efficient_thermal_transfer",
		"Efficient Thermal Transfer",
		"Reduces the Heat input required by Infernal Condensation by 25%.",
		ResourceIds.HEAT,
		25000.0,
		[
			UpgradeEffect.modifier(
				"thermal_furnace",
				ModifierTypes.INPUT_DRAW,
				0.75
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
		"thermal_furnace"
	)
	
	return Upgrade.new(definition)


# -------------------------------------------------------------------
# Matter Furnace upgrades
# -------------------------------------------------------------------

func _create_thermal_conversion() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"thermal_conversion",
		"Thermal Conversion",
		"Improves Matter Furnace conversion by 10% per level, while increasing its Matter consumption by 10% per level.",
		ResourceIds.HEAT,
		2500.0,
		[
			UpgradeEffect.modifier(
				"matter_furnace",
				ModifierTypes.PRODUCTION,
				1.10
			),
			UpgradeEffect.modifier(
				"matter_furnace",
				ModifierTypes.INPUT_DRAW,
				1.10
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
		1.35
	)
	
	return Upgrade.new(definition)


func _create_matter_refinement() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"matter_refinement",
		"Matter Refinement",
		"Refines the matter before combustion, reducing material consumption and improving the efficiency of furnace expansion.",
		ResourceIds.HEAT,
		80000.0,
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
				5
			)
		],
		false,
		"",
		"matter_furnace"
	)
	
	return Upgrade.new(definition)


# -------------------------------------------------------------------
# Ash Management
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
	
# -------------------------------------------------------------------
# Infernal Forge
# -------------------------------------------------------------------

func _create_infernal_forge_unlock() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"infernal_forge_unlock",
		"Crystallization",
		"Unlocks the Infernal Forge. Each Crystallized Flame makes Heat increasingly difficult to produce.",
		ResourceIds.MATTER,
		100.0,
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
				"crystallization_heat",
				ResourceIds.HEAT
			),
			UpgradeEffect.dynamic_resource_modifier(
				"",
				ModifierTypes.PRODUCTION,
				0.8,
				ResourceIds.CRYSTALIZED_FLAME,
				Modifier.DYNAMIC_RESOURCE_EXPONENT,
				"crystallization_matter",
				ResourceIds.MATTER
			)
		],
		[],
		false,
		"",
		"infernal_forge"
	)
	
	return Upgrade.new(definition)


func _create_infernal_forge_immunity() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"infernal_forge_immunity",
		"Forge Immunity",
		"The Infernal Forge becomes immune to Ashen Contamination and the effects of Crystallization.",
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
		35000.0,
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
		"thermal_furnace"
	)
	
	return Upgrade.new(definition)


func _create_thermal_furnace_mastery() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"thermal_furnace_mastery",
		"Infernal Condensation Mastery",
		"Each level of Infernal Condensation increases the production of all its outputs.",
		ResourceIds.HEAT,
		50000.0,
		[
			UpgradeEffect.dynamic_generator_modifier(
				"thermal_furnace",
				ModifierTypes.PRODUCTION,
				0.01,
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
		"thermal_furnace"
	)
	
	return Upgrade.new(definition)


func _create_thermal_furnace_efficiency() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"thermal_furnace_efficiency",
		"Condensation Efficiency",
		"Improves the construction process of Infernal Condensation, lowering cost scaling and increasing resistance to Ashen Contamination.",
		ResourceIds.HEAT,
		75000.0,
		[
			UpgradeEffect.modifier(
				"thermal_furnace",
				ModifierTypes.COST_SCALING,
				0.98
			),
			UpgradeEffect.sensitivity(
				"thermal_furnace",
				"ashen_contamination",
				0.5
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
		"thermal_furnace_specialization"
	)
	
	return Upgrade.new(definition)


func _create_thermal_purity() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"thermal_purity",
		"Condensation Purity",
		"Reduces Infernal Condensation's sensitivity to Ashen Contamination.",
		ResourceIds.HEAT,
		50000.0,
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
		"thermal_furnace_specialization"
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


func get_heat_leak_per_second() -> float:
	var heat = get_resource_amount(
		ResourceIds.HEAT
	)
	
	if heat <= heat_leak_threshold:
		return 0.0
	
	var excess_heat = (
		heat - heat_leak_threshold
	)
	
	var normalized_excess = (
		excess_heat
		/ heat_leak_threshold
	)
	
	return (
		heat_leak_base
		+ heat_leak_scaling
		* pow(
			normalized_excess,
			heat_leak_exponent
		)
	)
