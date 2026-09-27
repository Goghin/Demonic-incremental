class_name ThermalCompressor
extends RefCounted


static func create() -> Generator:
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
				32.0,
				true
			),
			GeneratorIO.new(
				ResourceIds.ASH,
				8
			)
		],
		1200000.0,
		1.4,
		ResourceIds.HEAT,
		false,
		0.0,
		[],
		"res://Generators/GeneratorDefinitions/Thermal_Compressor.png"
		
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	generator.initial_unlocked = false
	
	return generator
