class_name InfernalCondensation
extends RefCounted


static func create() -> Generator:
	var normal_mode = GeneratorOperationMode.new(
		"normal",
		"Normal",
		"Condenses immense quantities of Heat into Matter, producing Ash as a byproduct.",
		1.0,
		1.0,
		1.0,
		0.0,
		[
			GeneratorIO.new(
				ResourceIds.HEAT,
				1000.0
			)
		],
		[
			GeneratorIO.new(
				ResourceIds.MATTER,
				0.25,
				true
			),
			GeneratorIO.new(
				ResourceIds.ASH,
				0.3
			)
		]
	)
	
	var definition = GeneratorDefinition.new(
		"thermal_furnace",
		"Infernal Condensation",
		5000.0,
		1.22,
		ResourceIds.HEAT,
		false,
		"res://Generators/GeneratorDefinitions/Thermal_Condensation.png",
		[
			normal_mode
		]
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	generator.initial_unlocked = false
	
	return generator
