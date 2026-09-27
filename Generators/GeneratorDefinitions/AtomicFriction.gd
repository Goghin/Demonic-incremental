class_name AtomicFriction
extends RefCounted


static func create() -> Generator:
	var definition = GeneratorDefinition.new(
		"atomic_friction",
		"Atomic Friction",
		[],
		[
			GeneratorIO.new(
				ResourceIds.HEAT,
				3.0
			)
		],
		6.0,
		1.22,
		ResourceIds.HEAT,
		false,
		0.0,
		[],
		"res://Generators/GeneratorDefinitions/Atomic_Friction.png"
	)
	
	var generator = Generator.new(definition)
	generator.level = 1
	generator.unlocked = true
	generator.initial_unlocked = true
	
	return generator
