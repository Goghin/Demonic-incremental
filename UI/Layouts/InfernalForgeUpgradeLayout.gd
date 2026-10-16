class_name InfernalForgeUpgradeLayout
extends GeneratorUpgradeLayout


func _init() -> void:
	add_node("infernal_forge_refinement", 1, 0)
	add_node("infernal_forge_careful_mode", 0, 1)
	add_node("infernal_forge_fast_mode", 2, 1)
	add_node("infernal_forge_infernal_mode", 1, 2)
	add_node("infernal_forge_ash_adaptation", 0, 2)
	add_node("infernal_forge_careful_ash_resistance", 0, 3)

	add_connection(
		"infernal_forge_fast_mode",
		"infernal_forge_infernal_mode"
	)
	add_connection(
		"infernal_forge_careful_mode",
		"infernal_forge_ash_adaptation"
	)
	add_connection(
		"infernal_forge_ash_adaptation",
		"infernal_forge_careful_ash_resistance"
	)
