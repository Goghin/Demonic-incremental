class_name LavaMiteColony
extends RefCounted


static func create() -> Generator:
	var normal_mode = GeneratorOperationMode.new(
		"normal",
		"Normal",
		"Maintains a colony of Lava Mites that converts Heat, Matter, and Ash into Essence.",
		1.0,
		1.0,
		1.0,
		0.0,
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
		]
	)
	
	var definition = GeneratorDefinition.new(
		"lava_mite_colony",
		"Lava Mite Colony",
		150.0,
		1.2,
		ResourceIds.MATTER,
		false,
		"res://Generators/GeneratorDefinitions/Lava_Mite_Colony.png",
		[
			normal_mode
		]
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	generator.initial_unlocked = false
	
	return generator
