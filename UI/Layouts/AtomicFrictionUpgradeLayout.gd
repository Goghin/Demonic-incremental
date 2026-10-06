
class_name AtomicFrictionUpgradeLayout
extends GeneratorUpgradeLayout


func _init() -> void:

	# First stage
	add_node(
		"atomic_friction_optimization",
		1,
		0
	)

	# Level 25 choice
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

	# Convergence / next generator
	add_node(
		"molecular_agitation",
		1,
		2
	)

	# Level 40 milestone
	add_node(
		"atomic_process_optimization",
		1,
		3
	)

	# Level 45 specialization
	add_node(
		"efficient_atomic_processing",
		0,
		4
	)

	add_node(
		"atomic_mastery",
		2,
		4
	)

	# Level 65 late-game specialization
	add_node(
		"crystallization_adaptation",
		0,
		6
	)

	add_node(
		"contamination_adaptation",
		2,
		6
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

	# Both choices converge
	add_connection(
		"atomic_reorganization",
		"molecular_agitation"
	)

	add_connection(
		"atomic_friction_refinement",
		"molecular_agitation"
	)

	# Level 40 milestone
	add_connection(
		"molecular_agitation",
		"atomic_process_optimization"
	)

	# Level 45 specialization
	add_connection(
		"atomic_process_optimization",
		"efficient_atomic_processing"
	)

	add_connection(
		"atomic_process_optimization",
		"atomic_mastery"
	)

	# Level 65 specialization
	add_connection(
		"efficient_atomic_processing",
		"crystallization_adaptation"
	)

	add_connection(
		"atomic_mastery",
		"crystallization_adaptation"
	)

	add_connection(
		"efficient_atomic_processing",
		"contamination_adaptation"
	)

	add_connection(
		"atomic_mastery",
		"contamination_adaptation"
	)
