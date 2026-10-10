class_name TimeManager
extends RefCounted


var simulation_statistics: ResourceStatistics

var simulation_tick: int = 0
var simulation_total_ticks: int = 0

var offline_simulation_active: bool = false


signal offline_simulation_progress(
	current_tick: int,
	total_ticks: int
)


const MAX_STEP: float = 0.1

# Offline simulation has its own step limit so it can be optimized
# independently of normal gameplay. Keep this at MAX_STEP until
# larger-step simulation has been validated against the normal loop.
const OFFLINE_MAX_GAME_STEP: float = MAX_STEP
const OFFLINE_MAX_REAL_STEP: float = 0.1

const PROGRESS_UPDATE_INTERVAL: int = 100
const STABILIZATION_DURATION: float = 180.0

const DORMANCY_DELAY: float = 600.0
const DORMANCY_DURATION: float = 13800.0
const DORMANCY_MAX_PENALTY: float = 0.90
const DORMANCY_RECOVERY_TIME: float = 60.0


var simulation: Simulation

var time_scale: float = 1.0

var session_time: float = 0.0
var active_time: float = 0.0
var offline_time: float = 0.0
var game_time: float = 0.0

# Real time elapsed since the current realm was created.
# This includes stabilization time.
var prestige_time: float = 0.0

var last_real_timestamp: int = 0
var current_offline_duration: float = 0.0

var dormancy_recovery_remaining: float = 0.0

# Stabilization is a real-time countdown.
# While active, flame reassignment remains available.
var stabilization_countdown_active: bool = false
var stabilization_remaining: float = 0.0


func _init(game_simulation: Simulation) -> void:
	simulation = game_simulation
	simulation_statistics = ResourceStatistics.new()
	last_real_timestamp = Time.get_unix_time_from_system()


func update(real_delta: float) -> void:
	if real_delta <= 0.0:
		return

	session_time += real_delta
	active_time += real_delta
	prestige_time += real_delta

	_update_stabilization_countdown(
		real_delta
	)

	if dormancy_recovery_remaining > 0.0:
		var recovery_amount = (
			simulation.state.get_lava_mite_dormancy_penalty()
			* real_delta
			/ dormancy_recovery_remaining
		)

		var current_penalty = (
			simulation.state.get_lava_mite_dormancy_penalty()
		)

		var new_penalty = max(
			current_penalty - recovery_amount,
			0.0
		)

		simulation.state.set_lava_mite_dormancy_penalty(
			new_penalty
		)

		dormancy_recovery_remaining -= real_delta

	if dormancy_recovery_remaining <= 0.0:
		simulation.state.set_lava_mite_dormancy_penalty(
			0.0
		)

		dormancy_recovery_remaining = 0.0

	var game_delta = real_delta * time_scale

	advance(game_delta)


func simulate_offline(seconds: float) -> void:
	if seconds <= 0.0:
		return

	simulation_statistics.reset()
	offline_simulation_active = true

	# Progress represents REAL/OFFLINE time, not game time.
	# Calculate the expected number of steps using the offline step limits.
	var real_step_limit = OFFLINE_MAX_REAL_STEP
	if time_scale > 0.0:
		real_step_limit = min(
			real_step_limit,
			OFFLINE_MAX_GAME_STEP / time_scale
		)

	simulation_tick = 0
	simulation_total_ticks = ceili(
		seconds / real_step_limit
	)

	simulation.state.simulation_statistics = simulation_statistics
	offline_simulation_progress.emit(
		simulation_tick,
		simulation_total_ticks
	)

	var remaining = seconds
	current_offline_duration = 0.0

	while remaining > 0.0:
		# Bound both real time and game time. This keeps the offline
		# stepper independent from advance(), which is used in normal play.
		var step = min(
			remaining,
			real_step_limit
		)

		# These values represent real/offline time.
		offline_time += step
		current_offline_duration += step
		prestige_time += step

		_update_stabilization_countdown(step)

		simulation.state.set_lava_mite_dormancy_penalty(
			get_dormancy_penalty(current_offline_duration)
		)

		var game_seconds = step * time_scale
		if game_seconds > 0.0:
			_advance_offline_step(game_seconds)

		simulation_tick += 1
		remaining = max(0.0, remaining - step)

		if simulation_tick % PROGRESS_UPDATE_INTERVAL == 0:
			offline_simulation_progress.emit(
				simulation_tick,
				simulation_total_ticks
			)

			# Give the loading screen a chance to redraw.
			await Engine.get_main_loop().process_frame

	# Make sure progress reaches exactly 100%, including for very short
	# durations that don't hit a progress-update boundary.
	simulation_tick = simulation_total_ticks
	offline_simulation_progress.emit(
		simulation_tick,
		simulation_total_ticks
	)

	await Engine.get_main_loop().process_frame
	offline_simulation_active = false


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
		remaining = max(0.0, remaining - step)


# Process one offline simulation step. Kept separate from normal gameplay
# so offline-specific optimizations can be introduced without changing
# the regular simulation loop.
func _advance_offline_step(game_seconds: float) -> void:
	simulation.update(
		game_seconds,
		offline_simulation_active
	)
	game_time += game_seconds

# ----------------------------------------------------------------
# Prestige Time
# ----------------------------------------------------------------

func reset_prestige_time() -> void:
	prestige_time = 0.0


# ----------------------------------------------------------------
# Stabilization
# ----------------------------------------------------------------

func start_stabilization_countdown() -> bool:
	if stabilization_countdown_active:
		return false

	stabilization_countdown_active = true
	stabilization_remaining = STABILIZATION_DURATION

	return true


func cancel_stabilization_countdown() -> void:
	stabilization_countdown_active = false
	stabilization_remaining = 0.0


func _update_stabilization_countdown(
	real_seconds: float
	) -> void:

	if not stabilization_countdown_active:
		return

	if real_seconds <= 0.0:
		return

	stabilization_remaining -= real_seconds

	if stabilization_remaining > 0.0:
		return

	stabilization_remaining = 0.0
	stabilization_countdown_active = false

	if simulation.state.realm_stabilized:
		return

	simulation.state.stabilize_realm()


func is_stabilization_countdown_active() -> bool:
	return stabilization_countdown_active


func get_stabilization_remaining() -> float:
	return stabilization_remaining


# ----------------------------------------------------------------
# Timestamps / Offline Time
# ----------------------------------------------------------------

func get_current_timestamp() -> int:
	return Time.get_unix_time_from_system()


func get_offline_seconds() -> float:
	var current_timestamp = get_current_timestamp()

	var elapsed = (
		current_timestamp
		- last_real_timestamp
	)

	if elapsed < 0:
		return 0.0

	return float(elapsed)


func process_offline_time() -> float:
	var offline_seconds = get_offline_seconds()

	if offline_seconds <= 0.0:
		return 0.0

	await simulate_offline(
		offline_seconds
	)

	current_offline_duration = 0.0

	var current_penalty = (
		simulation.state.get_lava_mite_dormancy_penalty()
	)

	var max_penalty = (
		simulation.state.get_lava_mite_dormancy_max_penalty()
	)

	if max_penalty > 0.0:
		dormancy_recovery_remaining = (
			current_penalty
			/ max_penalty
			* DORMANCY_RECOVERY_TIME
		)
	else:
		dormancy_recovery_remaining = 0.0

	update_timestamp()

	simulation.state.simulation_statistics = null

	return offline_seconds


func update_timestamp() -> void:
	last_real_timestamp = get_current_timestamp()


# ----------------------------------------------------------------
# Dormancy
# ----------------------------------------------------------------

func get_dormancy_penalty(
	offline_seconds: float
	) -> float:

	var dormancy_delay = (
		simulation.state.get_lava_mite_dormancy_delay()
	)

	var dormancy_duration = (
		simulation.state.get_lava_mite_dormancy_duration()
	)

	var max_penalty = (
		simulation.state.get_lava_mite_dormancy_max_penalty()
	)

	if offline_seconds <= dormancy_delay:
		return 0.0

	var dormancy_time = (
		offline_seconds
		- dormancy_delay
	)

	if dormancy_duration <= 0.0:
		return max_penalty

	var progress = clamp(
		dormancy_time
		/ dormancy_duration,
		0.0,
		1.0
	)

	return progress * max_penalty
