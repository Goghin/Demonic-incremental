class_name InfernalForgeUpgradeLayout
extends GeneratorUpgradeLayout


func _init() -> void:
	# Crystallization unlocks the Infernal Forge and its core trade-off.
	add_node("infernal_forge_unlock", 1, 0)

	# Once the forge is available, choose its passive protection or improve
	# the cost of starting its crystallization cycle.
	add_node("infernal_forge_immunity", 0, 1)
	add_node("infernal_forge_refinement", 2, 1)

	add_connection(
		"infernal_forge_unlock",
		"infernal_forge_immunity"
	)

	add_connection(
		"infernal_forge_unlock",
		"infernal_forge_refinement"
	)
