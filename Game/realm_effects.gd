class_name RealmEffects
extends RefCounted


const STABILITY_THRESHOLD_BONUS: float = 0.05
const UNASSIGNED_STABILITY_BONUS: float = 0.01

var heat_leak_threshold: float = 0.0


func rebuild(
	eternal_flame_state: EternalFlameState,
	base_heat_leak_threshold: float
	) -> void:
	var stability = eternal_flame_state.stability
	var unassigned_flames = (
		eternal_flame_state.get_unassigned_flames()
	)
	
	var threshold_multiplier = (
		1.0
		+ stability * STABILITY_THRESHOLD_BONUS
		+ unassigned_flames * UNASSIGNED_STABILITY_BONUS
	)
	
	heat_leak_threshold = (
		base_heat_leak_threshold
		* threshold_multiplier
	)
