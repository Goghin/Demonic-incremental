class_name RealmConfiguration
extends RefCounted


var stability: int = 0
var density: int = 0
var integrity: int = 0
var intensity: int = 0
var resonance: int = 0

var locked: bool = false


func get_assigned_flames() -> int:
	return (
		stability
		+ density
		+ integrity
		+ intensity
		+ resonance
	)


func can_assign_flame() -> bool:
	return not locked


func assign_flame(
	stat_name: String
	) -> bool:
	
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

func can_remove_flame(
	stat_name: String
	) -> bool:
	
	if locked:
		return false
	
	return get_stat_value(stat_name) > 0



func remove_flame(
	stat_name: String
	) -> bool:
	
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


func get_stat_value(
	stat_name: String
	) -> int:
	
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


func lock() -> void:
	locked = true


func unlock() -> void:
	locked = false


func reset() -> void:
	stability = 0
	density = 0
	integrity = 0
	intensity = 0
	resonance = 0
	locked = false
