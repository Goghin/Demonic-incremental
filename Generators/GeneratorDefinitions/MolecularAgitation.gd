class_name MolecularAgitation
extends RefCounted


static func create() -> Generator:
	var definition = GeneratorDefinition.new(
		"molecular_agitation",
		"Molecular Agitation",
		[],
		[
			GeneratorIO.new(
				ResourceIds.HEAT,
				45.0
			)
		],
		250.0,
		1.22,
		ResourceIds.HEAT,
		false,
		0.0,
		[],
		"res://Generators/GeneratorDefinitions/Molecular_Agitation.png"
		
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	generator.initial_unlocked = false
	
	return generator
