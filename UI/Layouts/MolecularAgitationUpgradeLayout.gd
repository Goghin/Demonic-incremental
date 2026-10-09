class_name MolecularAgitationUpgradeLayout
extends GeneratorUpgradeLayout

func _init() -> void:
	# Main progression
	add_node("molecular_resonance", 1, 0)

	# Level 20 specialization choice
	add_node("resonant_containment", 0, 1)
	add_node("agitation_optimization", 2, 1)
	
	# Unlock the next generator
	add_node("unlock_infernal_condensation", 1, 2)
	# Refinement after the specialization branches
	
	add_node("molecular_agitation_refinement", 1, 3)

	# Atomic Friction synergy branch
	add_node("molecular_agitation_boost", 0, 4)
	add_node("molecular_agitation_expansion", 2, 4)



	# Main progression into the specialization choice
	add_connection(
		"molecular_resonance",
		"resonant_containment"
	)
	add_connection(
		"molecular_resonance",
		"agitation_optimization"
	)

	# Specializations rejoin at refinement
	add_connection(
		"resonant_containment",
		"molecular_agitation_refinement"
	)
	add_connection(
		"agitation_optimization",
		"molecular_agitation_refinement"
	)

	# Atomic Friction synergy branch
	add_connection(
		"molecular_agitation_refinement",
		"molecular_agitation_boost"
	)
	add_connection(
		"molecular_agitation_refinement",
		"molecular_agitation_expansion"
	)
