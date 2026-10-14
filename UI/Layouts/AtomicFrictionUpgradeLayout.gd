class_name AtomicFrictionUpgradeLayout
extends GeneratorUpgradeLayout


func _init() -> void:
	# First stage
	add_node(
		"atomic_friction_optimization",
		1,
		0
	)

	# Optional Essence-producing operating mode
	add_node(
		"intensified_friction_essence",
		3,
		0
	)

	# Level 20 choice
	add_node(
		"atomic_reorganization",
		0,
		1
	)

	add_node(
		"atomic_friction_refinement",
		2,
		1
	)

	# Level 25 convergence / next generator
	add_node(
		"molecular_agitation",
		1,
		2
	)

	# Level 35 specialization choice
	add_node(
		"efficient_atomic_processing",
		0,
		3
	)

	add_node(
		"atomic_mastery",
		2,
		3
	)

	# Level 40 milestone
	add_node(
		"atomic_process_optimization",
		1,
		4
	)

	# Level 55 late-game specialization
	add_node(
		"crystallization_adaptation",
		0,
		5
	)

	add_node(
		"contamination_adaptation",
		2,
		5
	)

	# First progression
	add_connection(
		"atomic_friction_optimization",
		"atomic_reorganization"
	)

	add_connection(
		"atomic_friction_optimization",
		"atomic_friction_refinement"
	)

	# Both level 20 choices converge
	add_connection(
		"atomic_reorganization",
		"molecular_agitation"
	)

	add_connection(
		"atomic_friction_refinement",
		"molecular_agitation"
	)

	# Level 35 specializations follow the level 25 unlock
	add_connection(
		"molecular_agitation",
		"efficient_atomic_processing"
	)

	add_connection(
		"molecular_agitation",
		"atomic_mastery"
	)

	# Both specializations lead to the level 40 milestone
	add_connection(
		"efficient_atomic_processing",
		"atomic_process_optimization"
	)

	add_connection(
		"atomic_mastery",
		"atomic_process_optimization"
	)

	# Level 55 adaptations follow the level 40 milestone
	add_connection(
		"atomic_process_optimization",
		"crystallization_adaptation"
	)

	add_connection(
		"atomic_process_optimization",
		"contamination_adaptation"
	)
