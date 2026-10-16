class_name ThermalCompressor
extends RefCounted


static func create() -> Generator:
	var compression_mode = GeneratorOperationMode.new(
		"compression",
		"Compression",
		"Converts 5,000 Matter and 100 Essence into 1 Nexum. Nexum is stored safely without decay and does not contribute to the realm's thermal bonus.",
		1.0,
		1.0,
		1.0,
		0.0,
		[
			GeneratorIO.new(
				ResourceIds.MATTER,
				5000.0
			),
			GeneratorIO.new(
				ResourceIds.ESSENCE,
				100.0
			)
		],
		[
			GeneratorIO.new(
				ResourceIds.NEXUM,
				1.0,
				true
			)
		],
		[],
		false
	)

	var definition = GeneratorDefinition.new(
		"thermal_compressor",
		"Arcane Compressor",
		1200000.0,
		1.4,
		ResourceIds.HEAT,
		false,
		"res://Generators/GeneratorDefinitions/Thermal_Compressor.png",
		[
			compression_mode
		]
	)

	var generator = Generator.new(definition)
	generator.unlocked = false
	generator.initial_unlocked = false

	return generator
