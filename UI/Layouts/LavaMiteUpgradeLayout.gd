class_name LavaMiteUpgradeLayout
extends GeneratorUpgradeLayout


func _init() -> void:

	# Main progression
	add_node("lava_mite_husbandry", 1, 0)

	# Choice 1
	add_node("lava_mite_refinement", 0, 1)
	add_node("lava_mite_improved_adaptation", 2, 1)

	# Back to middle
	add_node("lava_mite_metabolism", 1, 2)

	# Essence specialization
	add_node("lava_mite_essence", 3, 2)
	add_node("lava_mite_essence_adaptation", 3, 3)

	# Choice 2
	add_node("lava_mite_colony_growth", 0, 3)
	add_node("lava_mite_dormancy_delay", 2, 3)

	# Back to middle
	add_node("improved_lava_mite_colony_management", 1, 4)

	# Later progression
	add_node("lava_mite_dormancy_conditioning", 1, 5)
	add_node("lava_mite_dormancy_resilience", 1, 6)


	# Choice 1
	add_connection(
		"lava_mite_husbandry",
		"lava_mite_refinement"
	)

	add_connection(
		"lava_mite_husbandry",
		"lava_mite_improved_adaptation"
	)

	# Return to middle
	add_connection(
		"lava_mite_refinement",
		"lava_mite_metabolism"
	)

	add_connection(
		"lava_mite_improved_adaptation",
		"lava_mite_metabolism"
	)

	# Essence branch
	add_connection(
		"lava_mite_metabolism",
		"lava_mite_essence"
	)

	# Improve Essence extraction after unlocking the Essence output
	add_connection(
		"lava_mite_essence",
		"lava_mite_essence_adaptation"
	)

	# Choice 2
	add_connection(
		"lava_mite_metabolism",
		"lava_mite_colony_growth"
	)

	add_connection(
		"lava_mite_metabolism",
		"lava_mite_dormancy_delay"
	)

	# Return to middle
	add_connection(
		"lava_mite_colony_growth",
		"improved_lava_mite_colony_management"
	)

	add_connection(
		"lava_mite_dormancy_delay",
		"improved_lava_mite_colony_management"
	)

	# Main progression
	add_connection(
		"improved_lava_mite_colony_management",
		"lava_mite_dormancy_conditioning"
	)

	add_connection(
		"lava_mite_dormancy_conditioning",
		"lava_mite_dormancy_resilience"
	)
