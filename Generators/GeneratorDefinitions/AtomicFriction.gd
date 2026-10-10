class_name AtomicFriction
extends RefCounted


static func create() -> Generator:
	var normal_mode = GeneratorOperationMode.new(
		"normal",
		"Normal",
		"Operates at standard efficiency.",
		1.00,
		1.00,
		1.00,
		0.0,
		[],
		[
			GeneratorIO.new(
				ResourceIds.HEAT,
				3.0
			)
		]
	)
	
	var intensified_friction_mode = GeneratorOperationMode.new(
		"intensified_friction",
		"Intensified Friction",
		"Forces atoms into more violent collisions, producing a small trickle of Essence instead of Heat.",
		1.0,
		1.0,
		1.0,
		0.0,
		[],
		[
			GeneratorIO.new(
				ResourceIds.ESSENCE,
				0.0001
			)
		]
	)
	

	
	intensified_friction_mode.initially_unlocked = false
	intensified_friction_mode.unlocked = false

	var definition = GeneratorDefinition.new(
		"atomic_friction",
		"Atomic Friction",
		15.0,
		1.22,
		ResourceIds.HEAT,
		false,
		"res://Generators/GeneratorDefinitions/Atomic_Friction.png",
		[
			normal_mode,
			intensified_friction_mode		
		]
	)
	
	var generator = Generator.new(definition)
	generator.level = 1
	generator.unlocked = true
	generator.initial_unlocked = true
	
	return generator
