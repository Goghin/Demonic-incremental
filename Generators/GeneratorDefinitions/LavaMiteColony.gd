class_name LavaMiteColony
extends RefCounted


static func create() -> Generator:
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
		"res://Generators/GeneratorDefinitions/Lava_Mite_Colony.png"
		
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	generator.initial_unlocked = false
	
	return generator
