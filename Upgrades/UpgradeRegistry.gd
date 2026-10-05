class_name UpgradeRegistry
extends RefCounted


static func create_upgrades() -> Dictionary:
	var upgrades: Dictionary = {}

	# Atomic Friction
	_register(upgrades, _create_atomic_friction_optimization())
	_register(upgrades, _create_atomic_reorganization())
	_register(upgrades, _create_efficient_atomic_processing())
	_register(upgrades, _create_atomic_friction_refinement())

	# Molecular Agitation
	_register(upgrades, _create_molecular_agitation_upgrade())
	_register(upgrades, _create_molecular_resonance())
	_register(upgrades, _create_resonant_containment())
	_register(upgrades, _create_agitation_optimization())
	_register(upgrades, _create_molecular_agitation_refinement())

	# Matter
	_register(upgrades, _create_atomic_mastery())
	_register(upgrades, _create_thermic_mass())
	_register(upgrades, _create_thermal_compressor_optimization())
	_register(upgrades, _create_thermal_compressor_efficiency())
	_register(upgrades, _create_high_pressure_compression())
	_register(upgrades, _create_thermal_recovery())

	# Infernal Condensation
	_register(upgrades, _create_thermal_furnace_optimization())
	_register(upgrades, _create_efficient_thermal_transfer())
	_register(upgrades, _create_thermal_furnace_refinement())

	# Ash Management / Lava Mites
	_register(upgrades, _create_ashen_contamination())
	_register(upgrades, _create_lava_mite_colony_unlock())
	_register(upgrades, _create_lava_mite_husbandry())
	_register(upgrades, _create_lava_mite_dormancy())
	_register(upgrades, _create_lava_mite_refinement())
	_register(upgrades, _create_lava_mite_adaptation())
	_register(upgrades, _create_lava_mite_essence())
	_register(upgrades, _create_essence_influence())

	# Matter Furnace
	_register(upgrades, _create_thermal_conversion())
	_register(upgrades, _create_matter_refinement())
	_register(upgrades, _create_matter_furnace_unlock())
	_register(upgrades, _create_matter_furnace_refinement())
	_register(upgrades, _create_matter_furnace_ash_reduction())

	# Infernal Forge
	_register(upgrades, _create_infernal_forge_unlock())
	_register(upgrades, _create_infernal_forge_immunity())
	_register(upgrades, _create_infernal_forge_refinement())

	# Infernal Condensation Specialization
	_register(upgrades, _create_thermal_ash_filtration())
	_register(upgrades, _create_thermal_furnace_mastery())
	_register(upgrades, _create_thermal_furnace_efficiency())
	_register(upgrades, _create_thermal_purity())

	return upgrades


static func _register(
	upgrades: Dictionary,
	upgrade: Upgrade
	) -> void:

	upgrades[upgrade.definition.id] = upgrade
	
	

# -------------------------------------------------------------------
# Atomic Friction upgrades
# -------------------------------------------------------------------

static func _create_atomic_friction_optimization() -> Upgrade:
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


static func _create_atomic_reorganization() -> Upgrade:
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


static func _create_efficient_atomic_processing() -> Upgrade:
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


static func _create_atomic_friction_refinement() -> Upgrade:
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
		1.85,
		"atomic_friction"
	)
	
	return Upgrade.new(definition)


# -------------------------------------------------------------------
# Molecular Agitation upgrades
# -------------------------------------------------------------------

static func _create_molecular_agitation_upgrade() -> Upgrade:
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


static func _create_molecular_resonance() -> Upgrade:
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


static func _create_resonant_containment() -> Upgrade:
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


static func _create_agitation_optimization() -> Upgrade:
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


static func _create_molecular_agitation_refinement() -> Upgrade:
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

static func _create_atomic_mastery() -> Upgrade:
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


static func _create_thermic_mass() -> Upgrade:
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

static func _create_thermal_compressor_optimization() -> Upgrade:
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
	
	
static func _create_thermal_compressor_efficiency() -> Upgrade:
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
	
static func _create_high_pressure_compression() -> Upgrade:
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
	
static func _create_thermal_recovery() -> Upgrade:
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

static func _create_thermal_furnace_optimization() -> Upgrade:
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


static func _create_efficient_thermal_transfer() -> Upgrade:
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


static func _create_thermal_furnace_refinement() -> Upgrade:
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

static func _create_ashen_contamination() -> Upgrade:
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


static func _create_lava_mite_colony_unlock() -> Upgrade:
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


static func _create_lava_mite_dormancy() -> Upgrade:
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

static func _create_lava_mite_husbandry() -> Upgrade:
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

static func _create_lava_mite_refinement() -> Upgrade:
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


static func _create_lava_mite_adaptation() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"lava_mite_adaptation",
		"Lava Mite Adaptation",
		"Lava Mites become increasingly active at higher Ash levels.",
		ResourceIds.MATTER,
		1500.0,
		[
			(
				UpgradeEffect.dynamic_resource_modifier(
				"lava_mite_colony",
				ModifierTypes.INPUT_DRAW,
				0.20,
				ResourceIds.ASH,
				Modifier.DYNAMIC_RESOURCE_POWER_THRESHOLD,
				"lava_mite_ash_adaptation",
				"",
				250.0,
				0.3
				)
			),
				(
				UpgradeEffect.dynamic_resource_modifier(
				"lava_mite_colony",
				ModifierTypes.PRODUCTION,
				0.30,
				ResourceIds.ASH,
				Modifier.DYNAMIC_RESOURCE_POWER_THRESHOLD,
				"lava_mite_ash_adaptation",
				"",
				250.0,
				0.4
				)
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

static func _create_lava_mite_essence() -> Upgrade:
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
			,UpgradeEffect.sensitivity(
				"lava_mite_colony",
				"ashen_contamination",
				0
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
	
static func _create_essence_influence() -> Upgrade:
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

static func _create_thermal_conversion() -> Upgrade:
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


static func _create_matter_refinement() -> Upgrade:
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


static func _create_matter_furnace_unlock() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"matter_furnace_unlock",
		"Matter Combustion",
		"Unlocks the Matter Furnace.",
		ResourceIds.MATTER,
		10.0,
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


static func _create_matter_furnace_refinement() -> Upgrade:
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

static func _create_matter_furnace_ash_reduction() -> Upgrade:
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

static func _create_infernal_forge_unlock() -> Upgrade:
	var definition = UpgradeDefinition.new(
		"infernal_forge_unlock",
		"Crystallization",
		"Unlocks the Infernal Forge. Each Crystallized Flame makes Heat increasingly difficult to produce.",
		ResourceIds.MATTER,
		50.0,
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


static func _create_infernal_forge_immunity() -> Upgrade:
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


static func _create_infernal_forge_refinement() -> Upgrade:
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

static func _create_thermal_ash_filtration() -> Upgrade:
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


static func _create_thermal_furnace_mastery() -> Upgrade:
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


static func _create_thermal_furnace_efficiency() -> Upgrade:
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


static func _create_thermal_purity() -> Upgrade:
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
