class_name TimeManager
extends RefCounted


const MAX_STEP: float = 0.1


var simulation: Simulation

var time_scale: float = 1.0

var session_time: float = 0.0
var active_time: float = 0.0
var offline_time: float = 0.0
var game_time: float = 0.0
var last_real_timestamp: int = 0
var current_offline_duration: float = 0.0

const DORMANCY_GRACE_PERIOD: float = 3600.0
const DORMANCY_REFERENCE_TIME: float = 86400.0
const DORMANCY_MAX_PENALTY: float = 0.90
const DORMANCY_RECOVERY_TIME: float = 60.0

var dormancy_recovery_remaining: float = 0.0

func _init(game_simulation: Simulation) -> void:
	simulation = game_simulation
	
	last_real_timestamp = Time.get_unix_time_from_system()


func update(real_delta: float) -> void:
	if real_delta <= 0.0:
		return
	
	session_time += real_delta
	active_time += real_delta
	
	if dormancy_recovery_remaining > 0.0:
		var recovery_amount = min(
			real_delta,
			dormancy_recovery_remaining
		)
		
		var current_penalty = simulation.state.get_lava_mite_dormancy_penalty()
		
		var recovery_progress = (
			recovery_amount
			/ DORMANCY_RECOVERY_TIME
		)
		
		var new_penalty = current_penalty * (
			1.0 - recovery_progress
		)
		
		simulation.state.set_lava_mite_dormancy_penalty(
			new_penalty
		)
		
		dormancy_recovery_remaining -= recovery_amount
	
	if dormancy_recovery_remaining <= 0.0:
		simulation.state.set_lava_mite_dormancy_penalty(0.0)
	
	var game_delta = real_delta * time_scale
	
	advance(game_delta)


func simulate_offline(seconds: float) -> void:
	if seconds <= 0.0:
		return
	
	var remaining = seconds
	
	current_offline_duration = 0.0
	
	while remaining > 0.0:
		var step = min(
			remaining,
			MAX_STEP
		)
		
		offline_time += step
		current_offline_duration += step
		
		simulation.state.set_lava_mite_dormancy_penalty(
			get_dormancy_penalty(
				current_offline_duration
			)
		)
		
		var game_seconds = step * time_scale
		
		advance(game_seconds)
		
		remaining -= step


func advance(game_seconds: float) -> void:
	if game_seconds <= 0.0:
		return
	
	var remaining = game_seconds
	
	while remaining > 0.0:
		var step = min(
			remaining,
			MAX_STEP
		)
		
		simulation.update(step)
		
		game_time += step
		remaining -= step


func get_current_timestamp() -> int:
	return Time.get_unix_time_from_system()


func get_offline_seconds() -> float:
	var current_timestamp = get_current_timestamp()
	
	var elapsed = current_timestamp - last_real_timestamp
	
	if elapsed < 0:
		return 0.0
	
	return float(elapsed)

func process_offline_time() -> float:
	var offline_seconds = get_offline_seconds()
	
	if offline_seconds <= 0.0:
		return 0.0
	
	simulate_offline(offline_seconds)
	
	current_offline_duration = 0.0
	dormancy_recovery_remaining = DORMANCY_RECOVERY_TIME
	
	update_timestamp()
	
	return offline_seconds
	
func update_timestamp() -> void:
	last_real_timestamp = get_current_timestamp()


func get_dormancy_penalty(
	offline_seconds: float
	) -> float:
	
	if offline_seconds <= DORMANCY_GRACE_PERIOD:
		return 0.0
	
	var dormancy_time = (
		offline_seconds
		- DORMANCY_GRACE_PERIOD
	)
	
	var dormancy_duration = (
		DORMANCY_REFERENCE_TIME
		- DORMANCY_GRACE_PERIOD
	)
	
	if dormancy_duration <= 0.0:
		return DORMANCY_MAX_PENALTY
	
	var progress = clamp(
		dormancy_time
		/ dormancy_duration,
		0.0,
		1.0
	)
	
	# Ease-in curve.
	progress = progress * progress
	
	return progress * DORMANCY_MAX_PENALTY
