class_name ThermalFurnaceUpgradeLayout
extends GeneratorUpgradeLayout

func _init() -> void:
	# Main progression
	add_node("thermal_furnace_optimization", 1, 0)

	# Choice 1
	add_node("efficient_thermal_transfer", 0, 1)
	add_node("thermal_furnace_refinement", 2, 1)

	# Back to middle
	add_node("thermal_ash_filtration", 1, 2)

	# Main progression
	add_node("thermal_furnace_mastery", 1, 3)

	# Final specialization
	add_node("thermal_furnace_efficiency", 0, 4)
	add_node("thermal_purity", 2, 4)

	# Choice 1
	add_connection(
		"thermal_furnace_optimization",
		"efficient_thermal_transfer"
	)

	add_connection(
		"thermal_furnace_optimization",
		"thermal_furnace_refinement"
	)

	# Return to middle
	add_connection(
		"efficient_thermal_transfer",
		"thermal_ash_filtration"
	)

	add_connection(
		"thermal_furnace_refinement",
		"thermal_ash_filtration"
	)

	# Main progression
	add_connection(
		"thermal_ash_filtration",
		"thermal_furnace_mastery"
	)

	# Final specialization
	add_connection(
		"thermal_furnace_mastery",
		"thermal_furnace_efficiency"
	)

	add_connection(
		"thermal_furnace_mastery",
		"thermal_purity"
	)
