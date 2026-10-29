extends SceneTree

const UserScope = preload("res://tests/experimental/offline_study_user_scope.gd")

const Fixtures = preload("res://tests/experimental/offline_integration_fixtures.gd")
const NativeClock = preload("res://tests/experimental/offline_native_time_manager.gd")
const Probe = preload("res://tests/experimental/crafting_native_probe.gd")
const Events = preload("res://tests/experimental/transaction_events.gd")
const View = preload("res://tests/experimental/exact_flow_view.gd")
var rows: Array[Dictionary] = []
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _native(label: String, duration: float, intrusive: bool) -> Dictionary:
	var state: GameState = Fixtures.make_state(label)
	var simulation: Simulation = Probe.new(state) if intrusive else Simulation.new(state)
	simulation.profiling_enabled = intrusive
	var journal: RefCounted = Events.new()
	journal.attach(simulation)
	var tm: RefCounted = NativeClock.new(simulation, journal)
	tm.last_real_timestamp = tm.fixed_now - duration
	var started: int = Time.get_ticks_usec()
	await tm.process_offline_time()
	var wall_usec: int = Time.get_ticks_usec() - started
	var row: Dictionary = {"fixture": label, "seconds": duration, "intrusive": intrusive, "wall_usec": wall_usec, "frame_wait_usec": tm.offline_frame_wait_usec, "native_phases": simulation.get_profile_report()}
	if intrusive:
		row["cycle_callbacks"] = simulation.metrics.duplicate(true)
		row["inventory"] = state.relic_manager.timings.duplicate(true)
		row["generation"] = state.relic_manager.generation_manager.timings.duplicate(true)
	return {"view": View.capture(simulation, journal, true), "clocks": var_to_bytes([tm.offline_time, tm.game_time, tm.prestige_time, tm.current_offline_duration, tm.dormancy_recovery_remaining, tm.last_real_timestamp, tm.simulation_statistics.to_dictionary()]), "row": row}

func _run() -> void:
	var user_error: String = UserScope.rejection()
	if not user_error.is_empty():
		push_error(user_error)
		quit(1)
		return
	for label: String in ["early", "consumer_50000", "earned_craft_near_completion", "auto_standard", "late_mixed"]:
		var seconds: float = 300.0 if label == "auto_standard" else 60.0
		var control: Dictionary = await _native(label, seconds, false)
		var measured: Dictionary = await _native(label, seconds, true)
		if control["view"] != measured["view"] or control["clocks"] != measured["clocks"]:
			failures.append("Intrusive native profile changed gameplay: " + label)
		rows.append(measured["row"])
	var screen: Control = load("res://UI/loading_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	var progress_samples: Array[int] = []
	for repeat: int in range(11):
		var started: int = Time.get_ticks_usec()
		for index: int in range(1000):
			screen.set_simulation_tick(index, 1000)
		progress_samples.append(Time.get_ticks_usec() - started)
	screen.queue_free()
	var output := FileAccess.open("res://tests/experimental/offline_integration_profiles.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"engine": Engine.get_version_info(), "cpu": OS.get_processor_name(), "intrusive_native_rows": rows, "progress_1000_calls_usec": progress_samples, "first_progress_sample_is_warmup": true, "failures": failures}, "\t") + "\n")
	for failure: String in failures:
		push_error(failure)
	print("OFFLINE_NATIVE_PROFILES failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
