class_name InfernalCondensation
extends RefCounted


static func create() -> Generator:
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
		"res://Generators/GeneratorDefinitions/Thermal_Condensation.png"
		
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	generator.initial_unlocked = false
	
	return generator
