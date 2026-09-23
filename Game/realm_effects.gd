class_name RealmEffects
extends RefCounted


const STABILITY_THRESHOLD_BONUS: float = 0.05
const UNASSIGNED_STABILITY_BONUS: float = 0.01

const DENSITY_THERMAL_MASS_BONUS: float = 0.05
const UNASSIGNED_DENSITY_THERMAL_MASS_BONUS: float = 0.01

const DENSITY_MATTER_DECAY_THRESHOLD_BONUS: float = 0.05
const UNASSIGNED_DENSITY_MATTER_DECAY_THRESHOLD_BONUS: float = 0.01

var heat_leak_threshold: float = 0.0
var matter_decay_threshold: float = 0.0
var thermal_mass_multiplier: float = 1.0


func rebuild(
	eternal_flame_state: EternalFlameState,
	base_heat_leak_threshold: float,
	base_matter_decay_threshold: float
	) -> void:
	
	var stability = eternal_flame_state.stability
	var density = eternal_flame_state.density
	
	var unassigned_flames = (
		eternal_flame_state.get_unassigned_flames()
	)
	
	# ----------------------------------------------------------------
	# Stability
	# ----------------------------------------------------------------
	
	var stability_multiplier = (
		1.0
		+ stability * STABILITY_THRESHOLD_BONUS
		+ unassigned_flames * UNASSIGNED_STABILITY_BONUS
	)
	
	heat_leak_threshold = (
		base_heat_leak_threshold
		* stability_multiplier
	)
	
	# ----------------------------------------------------------------
	# Density
	# ----------------------------------------------------------------
	
	thermal_mass_multiplier = (
		1.0
		+ density * DENSITY_THERMAL_MASS_BONUS
		+ unassigned_flames * UNASSIGNED_DENSITY_THERMAL_MASS_BONUS
	)
	
	var matter_decay_threshold_multiplier = (
		1.0
		+ density * DENSITY_MATTER_DECAY_THRESHOLD_BONUS
		+ unassigned_flames * UNASSIGNED_DENSITY_MATTER_DECAY_THRESHOLD_BONUS
	)
	
	matter_decay_threshold = (
		base_matter_decay_threshold
		* matter_decay_threshold_multiplier
	)
