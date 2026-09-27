class_name ThermalCompressor
extends RefCounted


static func create() -> Generator:
	var normal_mode = GeneratorOperationMode.new(
		"normal",
		"Normal",
		"Compresses immense quantities of Heat into Matter while producing Ash as a byproduct.",
		1.0,
		1.0,
		1.0,
		0.0,
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
				8.0
			)
		]
	)
	
	var definition = GeneratorDefinition.new(
		"thermal_compressor",
		"Thermal Compressor",
		1200000.0,
		1.4,
		ResourceIds.HEAT,
		false,
		"res://Generators/GeneratorDefinitions/Thermal_Compressor.png",
		[
			normal_mode
		]
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	generator.initial_unlocked = false
	
	return generator
