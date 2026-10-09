class_name MatterFurnaceUpgradeLayout
extends GeneratorUpgradeLayout


func _init() -> void:
	# Main progression
	add_node("thermal_conversion", 1, 0)

	# Specialization choice
	add_node("matter_furnace_refinement", 0, 1)
	add_node("matter_furnace_ash_reduction", 2, 1)

	# Final progression
	add_node("matter_refinement", 1, 2)

	# Specialization choice
	add_connection(
		"thermal_conversion",
		"matter_furnace_refinement"
	)

	add_connection(
		"thermal_conversion",
		"matter_furnace_ash_reduction"
	)

	# Return to middle
	add_connection(
		"matter_furnace_refinement",
		"matter_refinement"
	)

	add_connection(
		"matter_furnace_ash_reduction",
		"matter_refinement"
	)
