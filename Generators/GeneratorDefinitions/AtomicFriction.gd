class_name AtomicFriction
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
				3.0
			)
		]
	)
	
	var intensified_friction_mode = GeneratorOperationMode.new(
		"intensified_friction",
		"Intensified Friction",
		"Forces the atoms into more violent collisions, greatly increasing Heat production at increased Heat consumption.",
		1.0,
		2.0,
		1.0,
		0.0,
		[],
		[
			GeneratorIO.new(
				ResourceIds.HEAT,
				6.0
			)
		]
	)
	
	var ashen_friction_mode = GeneratorOperationMode.new(
		"ashen_friction",
		"Ashen Friction",
		"Allows friction to produce Ash as a byproduct, sacrificing part of its Heat production.",
		1.0,
		1.0,
		1.0,
		0.0,
		[],
		[
			GeneratorIO.new(
				ResourceIds.HEAT,
				1.5
			),
			GeneratorIO.new(
				ResourceIds.ASH,
				0.15
			)
		]
	)
	
	var definition = GeneratorDefinition.new(
		"atomic_friction",
		"Atomic Friction",
		6.0,
		1.22,
		ResourceIds.HEAT,
		false,
		"res://Generators/GeneratorDefinitions/Atomic_Friction.png",
		[
			normal_mode,
			intensified_friction_mode,
			ashen_friction_mode
		]
	)
	
	var generator = Generator.new(definition)
	generator.level = 1
	generator.unlocked = true
	generator.initial_unlocked = true
	
	return generator
