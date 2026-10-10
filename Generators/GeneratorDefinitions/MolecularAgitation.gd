class_name MolecularAgitation
extends RefCounted


static func create() -> Generator:
	var normal_mode = GeneratorOperationMode.new(
		"normal",
		"Normal",
		"Operates at standard efficiency.",
		1.0,
		1.0,
		1.0,
		0.0,
		[],
		[
			GeneratorIO.new(
				ResourceIds.HEAT,
				45.0
			),
			GeneratorIO.new(
				ResourceIds.ASH,
				0.1
			)
		]
	)
	
	var definition = GeneratorDefinition.new(
		"molecular_agitation",
		"Molecular Agitation",
		250.0,
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
