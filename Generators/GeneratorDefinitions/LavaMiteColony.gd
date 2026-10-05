class_name LavaMiteColony
extends RefCounted


static func create() -> Generator:
	var normal_mode = GeneratorOperationMode.new(
		"normal",
		"Normal",
		"Maintains a colony of Lava Mites that consumes Heat and Ash.",
		1.0,
		1.0,
		1.0,
		0.0,
		[
			GeneratorIO.new(
				ResourceIds.HEAT,
				100.0
			),
			#Test as negative output
			GeneratorIO.new(
				ResourceIds.ASH,
				0.5
			)
		],
		[
			
			#Starts locked, requires upgrade
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
		1000.0,
		1.22,
		ResourceIds.HEAT,
		false,
		"res://Generators/GeneratorDefinitions/Lava_Mite_Colony_2.png",
		[
			normal_mode
		]
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	generator.initial_unlocked = false
	
	return generator
