class_name InfernalForgeUpgradeLayout
extends GeneratorUpgradeLayout


func _init() -> void:
	# Refinement is the only upgrade that directly improves the Infernal Forge.
	add_node("infernal_forge_refinement", 1, 0)
