class_name UpgradeGroupRegistry
extends RefCounted


static func create_groups() -> Dictionary:
	var groups: Dictionary = {}

	_register(
		groups,
		UpgradeGroupDefinition.new(
			"atomic_friction",
			"Atomic Friction",
			"Develop the fundamental process of generating Heat through atomic friction."
		)
	)

	_register(
		groups,
		UpgradeGroupDefinition.new(
			"molecular_agitation",
			"Molecular Agitation",
			"Manipulate entire molecules to produce greater amounts of thermal energy."
		)
	)

	_register(
		groups,
		UpgradeGroupDefinition.new(
			"matter",
			"Matter",
			"Develop the realm's ability to retain, manipulate and exploit Matter."
		)
	)

	_register(
		groups,
		UpgradeGroupDefinition.new(
			"thermal_furnace",
			"Infernal Condensation",
			"Develop and refine the Infernal Condensation process that converts Heat into Matter."
		)
	)

	_register(
		groups,
		UpgradeGroupDefinition.new(
			"ash_management",
			"Ash Management",
			"Understand and control the consequences of Ash accumulation."
		)
	)

	_register(
		groups,
		UpgradeGroupDefinition.new(
			"matter_furnace",
			"Matter Furnace",
			"Develop the destruction and conversion of Matter back into thermal energy."
		)
	)

	_register(
		groups,
		UpgradeGroupDefinition.new(
			"infernal_forge",
			"Infernal Forge",
			"Push Matter through the Infernal Forge and begin the process of crystallization."
		)
	)

	_register(
		groups,
		UpgradeGroupDefinition.new(
			"thermal_furnace_specialization",
			"Infernal Condensation Specialization",
			"Choose one specialization for Infernal Condensation."
		)
	)

	return groups


static func _register(
	groups: Dictionary,
	group: UpgradeGroupDefinition
	) -> void:

	groups[group.id] = group
