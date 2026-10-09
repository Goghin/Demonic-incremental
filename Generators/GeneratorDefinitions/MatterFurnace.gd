class_name MatterFurnace
extends RefCounted


static func create() -> Generator:
	var normal_mode = GeneratorOperationMode.new(
		"normal",
		"Normal",
		"Converts Matter into Heat and Ash at standard efficiency.",
		1.0,
		1.0,
		1.0,
		0.0,
		[
			GeneratorIO.new(
				ResourceIds.MATTER,
				3.5
			)
		],
		[
			GeneratorIO.new(
				ResourceIds.HEAT,
				8500.0
			),
			GeneratorIO.new(
				ResourceIds.ASH,
				2.25
			)
		]
	)
	
	var ash_production_mode = GeneratorOperationMode.new(
		"ash_production",
		"Ash Production",
		"Forces the furnace toward Ash production, greatly increasing Ash output at the expense of Heat.",
		1.0,
		1.0,
		1.0,
		0.0,
		[],
		[
			GeneratorIO.new(
				ResourceIds.HEAT,
				1500.0
			),
			GeneratorIO.new(
				ResourceIds.ASH,
				12.0
			)
		]
	)
	
	var definition = GeneratorDefinition.new(
		"matter_furnace",
		"Matter Furnace",
		275.0,
		1.25,
		ResourceIds.MATTER,
		false,
		"res://Generators/GeneratorDefinitions/Matter_Furnace.png",
		[
			normal_mode,
			ash_production_mode
		]
	)
	
	var generator = Generator.new(definition)
	generator.unlocked = false
	generator.initial_unlocked = false
	
	return generator
