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
				ResourceIds.HEAT,
				10000
			),
			GeneratorIO.new(
				ResourceIds.MATTER,
				5
			)
		],
		[
			GeneratorIO.new(
				ResourceIds.ASH,
				6.0
			)
		],
		[
			GeneratorIO.new(
				ResourceIds.CRYSTALLIZED_FLAME,
				1.0,
				true
			)
		]
	)
	
	var careful_mode = GeneratorOperationMode.new(
		"careful",
		"Careful",
		"Runs a slower, controlled crystallization cycle with reduced Heat and Ash output.",
		1.0,
		1.0,
		1.0,
		900.0,
		[
			GeneratorIO.new(ResourceIds.HEAT, 5000.0),
			GeneratorIO.new(ResourceIds.MATTER, 5.0)
		],
		[
			GeneratorIO.new(ResourceIds.ASH, 3.0)
		],
		[
			GeneratorIO.new(ResourceIds.CRYSTALLIZED_FLAME, 1.0, true)
		]
	)
	careful_mode.initially_unlocked = false
	careful_mode.unlocked = false

	var fast_mode = GeneratorOperationMode.new(
		"fast",
		"Fast",
		"Accelerates crystallization at greatly increased Matter consumption and Ash output.",
		1.0,
		1.0,
		1.5,
		18.0,
		[
			GeneratorIO.new(ResourceIds.MATTER, 15.0)
		],
		[
			GeneratorIO.new(ResourceIds.ASH, 17.5)
		],
		[
			GeneratorIO.new(ResourceIds.CRYSTALLIZED_FLAME, 1.0, true)
		]
	)
	fast_mode.initially_unlocked = false
	fast_mode.unlocked = false

	var infernal_crystallization_mode = GeneratorOperationMode.new(
		"infernal_crystallization",
		"Infernal Crystallization",
		"Subjects the Forge to catastrophic conditions, forcing crystallization at an unimaginable rate.",
		1.0,
		1.0,
		15.0,
		20.0,
		[
			GeneratorIO.new(ResourceIds.MATTER, 50000.0)
		],
		[
			GeneratorIO.new(ResourceIds.ASH, 60000.0)
		],
		[
			GeneratorIO.new(ResourceIds.CRYSTALLIZED_FLAME, 1.0, true)
		]
	)
	infernal_crystallization_mode.initially_unlocked = false
	infernal_crystallization_mode.unlocked = false
	
	
	var definition = GeneratorDefinition.new(
		"infernal_forge",
		"Infernal Forge",
		1000000.0,
		2.0,
		ResourceIds.HEAT,
		true,
		"res://Generators/GeneratorDefinitions/Infernal_Forge.png",
		[
			normal_mode,
			careful_mode,
			fast_mode,
			infernal_crystallization_mode
		]
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	generator.initial_unlocked = false
	
	return generator
