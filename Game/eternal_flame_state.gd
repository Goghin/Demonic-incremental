class_name EternalFlameState
extends RefCounted


var eternal_flame: float = 0.0
var prestige_count: int = 0
var total_crystallized_flame: float = 0.0

var stability: int = 0
var density: int = 0
var integrity: int = 0
var intensity: int = 0
var resonance: int = 0


func get_assigned_flames() -> int:
	return (
		stability
		+ density
		+ integrity
		+ intensity		
		+ resonance
	)

func get_intensity_heat_production_factor() -> float:
	return (
		1.0
		+ 0.05 * intensity
		+ 0.01 * get_unassigned_flames()
	)
	
func get_integrity_contamination_factor() -> float:
	return (
		1.0
		+ 0.05 * integrity
		+ 0.01 * get_unassigned_flames()
	)

func get_density_matter_production_factor() -> float:
	return (
		1.0
		+ 0.05 * density
		+ 0.01 * get_unassigned_flames()
	)
	
func get_unassigned_flames() -> int:
	return max(
		0,
		int(eternal_flame) - get_assigned_flames()
	)


func can_assign_flame() -> bool:
	return get_unassigned_flames() > 0


func can_remove_flame(stat_name: String) -> bool:
	return get_stat_value(stat_name) > 0


func assign_flame(stat_name: String) -> bool:
	if not can_assign_flame():
		return false
	
	match stat_name:
		"integrity":
			integrity += 1
		"stability":
			stability += 1
		"intensity":
			intensity += 1
		"density":
			density += 1
		"resonance":
			resonance += 1
		_:
			return false
	
	return true


func remove_flame(stat_name: String) -> bool:
	if not can_remove_flame(stat_name):
		return false
	
	match stat_name:
		"integrity":
			integrity -= 1
		"stability":
			stability -= 1
		"intensity":
			intensity -= 1
		"density":
			density -= 1
		"resonance":
			resonance -= 1
		_:
			return false
	
	return true


func get_stat_value(stat_name: String) -> int:
	match stat_name:
		"integrity":
			return integrity
		"stability":
			return stability
		"intensity":
			return intensity
		"density":
			return density
		"resonance":
			return resonance
	
	return 0


func reset() -> void:
	eternal_flame = 0.0
	prestige_count = 0
	total_crystallized_flame = 0.0
	
	stability = 0
	intensity = 0
	density = 0
	resonance = 0
	integrity = 0
