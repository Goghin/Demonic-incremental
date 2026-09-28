class_name InfernalForge
extends RefCounted


static func create() -> Generator:
	var normal_mode = GeneratorOperationMode.new(
		"normal",
		"Normal",
		"Operates the Infernal Forge at standard efficiency.",
		1.0,
		1.0,
		1.0,
		600.0,
		[
			GeneratorIO.new(
				ResourceIds.MATTER,
				4.5
			)
		],
		[
			GeneratorIO.new(
				ResourceIds.ASH,
				5.0
			)
		],
		[
			GeneratorIO.new(
				ResourceIds.CRYSTALIZED_FLAME,
				1.0,
				true
			)
		]
	)
	
	var fast_crystallization_mode = GeneratorOperationMode.new(
		"fast_crystallization",
		"Fast Crystallization",
		"Accelerates crystallization at greatly increased resource consumption.",
		1.0,
		1.0,
		1.5,
		18.0,
		[
			GeneratorIO.new(
				ResourceIds.MATTER,
				15.0
			)
		],
		[
			GeneratorIO.new(
				ResourceIds.ASH,
				17.5
			)
		],
		[
			GeneratorIO.new(
				ResourceIds.CRYSTALIZED_FLAME,
				1.0,
				true
			)
		]
	)
	
	var violent_crystallization_mode = GeneratorOperationMode.new(
		"violent_crystallization",
		"Violent Crystallization",
		"Forces crystallization through immense pressure, consuming enormous quantities of Matter and Ash.",
		1.0,
		1.0,
		4.5,
		60.0,
		[
			GeneratorIO.new(
				ResourceIds.MATTER,
				2500.0
			)
		],
		[
			GeneratorIO.new(
				ResourceIds.ASH,
				3333.3333333
			)
		],
		[
			GeneratorIO.new(
				ResourceIds.CRYSTALIZED_FLAME,
				1.0,
				true
			)
		]
	)
	
	var infernal_crystallization_mode = GeneratorOperationMode.new(
		"infernal_crystallization",
		"Infernal Crystallization",
		"Subjects the Forge to catastrophic conditions, forcing crystallization at an unimaginable rate.",
		1.0,
		1.0,
		15.0,
		20.0,
		[
			GeneratorIO.new(
				ResourceIds.MATTER,
				50000.0
			)
		],
		[
			GeneratorIO.new(
				ResourceIds.ASH,
				60000.0
			)
		],
		[
			GeneratorIO.new(
				ResourceIds.CRYSTALIZED_FLAME,
				1.0,
				true
			)
		]
	)
	
	
	
	var definition = GeneratorDefinition.new(
		"infernal_forge",
		"Infernal Forge",
		10000000.0,
		2.0,
		ResourceIds.HEAT,
		true,
		"res://Generators/GeneratorDefinitions/Infernal_Forge.png",
		[
			normal_mode,
			fast_crystallization_mode,
			violent_crystallization_mode,
			infernal_crystallization_mode
		]
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	generator.initial_unlocked = false
	
	return generator
