extends SceneTree

const UserScope = preload("res://tests/experimental/offline_study_user_scope.gd")

const NativeClock = preload("res://tests/experimental/offline_native_time_manager.gd")
const Adapter = preload("res://tests/experimental/offline_kernel_time_manager.gd")
const Fixtures = preload("res://tests/experimental/offline_integration_fixtures.gd")
const View = preload("res://tests/experimental/exact_flow_view.gd")
const Events = preload("res://tests/experimental/transaction_events.gd")
const Oracle = preload("res://tests/experimental/transaction_tests.gd")
const Graph = preload("res://tests/experimental/offline_state_fingerprint.gd")
var failures: Array[String] = []
var rows: Array[Dictionary] = []
var progress: Array = []
var trace: Array[PackedByteArray] = []
var loading: Control
var results_panel: Control
var formatter_script: GDScript
var pending_achievements: Array[String] = []
var active_tm: RefCounted
var active_scope: String
var frame_changed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _clock(tm: TimeManager) -> Array:
	return [tm.time_scale, tm.session_time, tm.active_time, tm.offline_time, tm.game_time, tm.prestige_time, tm.last_real_timestamp, tm.current_offline_duration, tm.dormancy_recovery_remaining, tm.stabilization_countdown_active, tm.stabilization_remaining, tm.offline_simulation_active, tm.simulation_tick, tm.simulation_total_ticks, tm.simulation_statistics.to_dictionary()]

func _tick(tm: TimeManager) -> void:
	trace.append(var_to_bytes([View.capture(tm.simulation, tm.journal, true), _clock(tm)]))

func _progress(current: int, total: int) -> void:
	progress.append([current, total])
	loading.set_simulation_tick(current, total)
	if current >= 100 and not frame_changed:
		if active_scope == "observer_reentry":
			active_tm.simulation.relic_crafting_completed.disconnect(_observer)
			frame_changed = true
		elif active_scope == "frame_mutation":
			check(active_tm.simulation.buy_generator("atomic_friction", "frame_boundary"), "Frame purchase failed")
			frame_changed = true

func _achievement(id: String) -> void:
	if not pending_achievements.has(id):
		pending_achievements.append(id)

func _observer(_name: String, _quantity: int, _critical: bool) -> void:
	# Controlled external sink: presence must still force native dispatch.
	pass

func _run_case(label: String, seconds: float, accelerated: bool, scope: String, scale: float = 1.0, budget: float = 0.0, record: bool = false, instrument: bool = false) -> Dictionary:
	var fixture_started: int = Time.get_ticks_usec()
	var source: GameState = Fixtures.make_state(label)
	var saver := SaveManager.new()
	var source_clock: RefCounted = Adapter.new(Simulation.new(source))
	source_clock.fixed_now -= seconds
	check(saver.save_game(source, source_clock), "Fixture save failed")
	var fixture_usec: int = Time.get_ticks_usec() - fixture_started
	if OS.get_environment("TM_STUDY_MODE") == "confirm":
		results_panel.results_label.text = ""
		results_panel.duration_label.text = ""
		results_panel.visible = false
	results_panel.visible = false
	var pipeline_started: int = Time.get_ticks_usec()
	var start: int = Time.get_ticks_usec()
	var state := GameState.new()
	if scope != "production_logger":
		state.gameplay_log = preload("res://tests/experimental/autobuyer_fixtures.gd").TickLog.new()
	var simulation := Simulation.new(state)
	var journal: RefCounted = Events.new()
	journal.attach(simulation)
	if scope in ["observer", "observer_reentry"]:
		simulation.relic_crafting_completed.connect(_observer)
	var tm: RefCounted = Adapter.new(simulation, journal, accelerated) if accelerated or record or instrument else NativeClock.new(simulation, journal)
	if scope == "fractional_clock":
		tm.fixed_now += 0.125
	check(saver.load_game(state, tm), "Native save load failed")
	var restore_usec: int = Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	tm.cancel_stabilization_countdown()
	if not state.prestige_planning:
		state.realm_stabilized = true
		state.realm_configuration.lock()
	simulation.rebuild_upgrade_effects()
	if scope == "previous_packet":
		tm.packet_script = preload("res://tests/experimental/baselines/exact_flow_182e562_packet.gd")
	tm.rebuild_each_tick = scope == "per_tick_build"
	tm.diagnostic_idle_gate = scope == "diagnostic_idle_gate"
	tm.offline_work_budget_ms = budget
	tm.time_scale = scale
	tm.instrument = instrument
	tm.offline_simulation_progress.connect(_progress)
	if record:
		tm.on_tick = _tick
	active_tm = tm
	active_scope = scope
	frame_changed = false
	progress = []
	trace = []
	pending_achievements = []
	state.achievement_manager.update(state)
	var prepare_usec: int = Time.get_ticks_usec() - start
	if scope == "legacy_stabilization":
		state.realm_stabilized = false
		state.realm_configuration.unlock()
		tm.start_stabilization_countdown()
	var restored_timestamp: float = tm.last_real_timestamp
	state.achievement_manager.achievement_unlocked.connect(_achievement)
	var memory_before: int = OS.get_static_memory_usage()
	start = Time.get_ticks_usec()
	var requested: float = tm.get_offline_seconds()
	var elapsed_usec: int = Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	var processed: float = await tm.process_offline_time()
	var runtime_usec: int = Time.get_ticks_usec() - start
	var recovery_started: int = Time.get_ticks_usec()
	if scope == "recovery":
		for tick: int in range(620):
			tm.update(0.1)
		check(tm.dormancy_recovery_remaining == 0.0 and state.get_lava_mite_dormancy_penalty() == 0.0, "Recovery did not finish")
	var recovery_usec: int = Time.get_ticks_usec() - recovery_started
	var retained_memory: int = OS.get_static_memory_usage() - memory_before
	start = Time.get_ticks_usec()
	state.achievement_manager.update(state)
	state.achievement_manager.achievement_unlocked.disconnect(_achievement)
	var achievement_usec: int = Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	if processed > 0.0:
		check(saver.save_game(state, tm), "Final native save failed")
	var save_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	var finalization_usec: int = Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	var formatter: RefCounted = formatter_script.new()
	formatter.state = state
	formatter.time_manager = tm
	var result_text: String = formatter._build_offline_results(processed) if processed > 0.0 else ""
	if processed > 0.0:
		results_panel.show_results(processed, result_text)
	var result_data: Array = [processed, result_text, tm.simulation_statistics.to_dictionary(), tm.get_dormancy_penalty(processed), state.relic_manager.get_save_data(), state.achievement_manager.to_dictionary(), pending_achievements.duplicate()]
	var result_usec: int = Time.get_ticks_usec() - start
	var pipeline_usec: int = Time.get_ticks_usec() - pipeline_started
	var fingerprint: PackedByteArray = Graph.new().capture([simulation, journal, tm.simulation_statistics])
	var legacy_graph: PackedByteArray = PackedByteArray()
	if scope not in ["production_logger", "observer"]:
		var oracle: RefCounted = Oracle.new()
		legacy_graph = oracle.fingerprint(simulation, journal)
		check(oracle.failures.is_empty(), "Legacy graph scope failed")
	var clocks: PackedByteArray = var_to_bytes(_clock(tm))
	var result_bytes: PackedByteArray = var_to_bytes(result_data)
	check(processed == requested and requested == maxf(0.0, tm.fixed_now - restored_timestamp), "Elapsed mismatch " + label)
	check(progress.is_empty() if seconds <= 0.0 else progress[-1] == [tm.simulation_total_ticks, tm.simulation_total_ticks], "Final progress mismatch " + label)
	check(tm.packet == null and state.simulation_statistics == null, "Final ownership mismatch " + label)
	var row: Dictionary = {"fixture": label, "seconds": seconds, "scope": scope, "kernel": accelerated, "native_dispatch_wrapper": not accelerated and (record or instrument), "scale": scale, "budget_ms": budget, "fixture_setup_excluded_usec": fixture_usec, "pipeline_usec": pipeline_usec, "restored_timestamp": restored_timestamp, "restore_usec": restore_usec, "prepare_usec": prepare_usec, "elapsed_usec": elapsed_usec, "effective_requested_seconds": requested, "runtime_usec": runtime_usec, "recovery_usec": recovery_usec, "frame_wait_usec": tm.offline_frame_wait_usec, "yields": tm.offline_yield_count, "steps": tm.offline_steps_processed, "retained_memory_estimate_bytes": retained_memory, "achievement_usec": achievement_usec, "result_data_usec": result_usec, "finalization_usec": finalization_usec, "counters": tm.counters.duplicate(true), "progress_events": progress.size(), "saved_after_catchup": processed > 0.0, "results_shown": results_panel.visible, "native_event_count": journal.events.size(), "native_events": journal.events.duplicate(true), "game_seconds": tm.game_time, "offline_seconds": tm.offline_time}
	return {"row": row, "graph": fingerprint, "legacy_graph": legacy_graph, "clocks": clocks, "result": result_bytes, "trace": trace.duplicate(), "save": var_to_bytes(save_data)}

func _pair(label: String, seconds: float, scope: String, scale: float = 1.0, budget: float = 0.0, record: bool = false, repeat: int = 0, instrument: bool = false) -> void:
	var native: Dictionary
	var candidate: Dictionary
	if OS.get_environment("TM_STUDY_MODE") == "confirm" and repeat % 2 == 1:
		candidate = await _run_case(label, seconds, true, scope, scale, budget, record, instrument)
		native = await _run_case(label, seconds, false, scope, scale, budget, record, instrument)
	else:
		native = await _run_case(label, seconds, false, scope, scale, budget, record, instrument)
		candidate = await _run_case(label, seconds, true, scope, scale, budget, record, instrument)
	var events: Array = candidate["row"]["native_events"]
	if label == "critical_greater":
		var critical_reward: bool = false
		for event: Dictionary in events:
			critical_reward = critical_reward or (event["event"] == "relic" and bool(event.get("critical", false)))
		check(critical_reward, "Critical offline craft was not exercised")
	if label == "forge_together":
		var forge_reward: bool = false
		var relic_reward: bool = false
		for event: Dictionary in events:
			forge_reward = forge_reward or event["event"] in ["normal", "critical"]
			relic_reward = relic_reward or event["event"] == "relic"
		check(forge_reward and relic_reward, "Joint offline completion was not exercised")
	var counts: Dictionary = candidate["row"]["counters"]
	if scope in ["production_logger", "observer"]:
		check(counts["kernel_ticks"] == 0 and counts["fallback_ticks"] > 0, "Unsafe observer/logger admission")
	if scope == "observer_reentry":
		check(counts["kernel_ticks"] > 0 and counts["fallback_ticks"] >= 100, "Observer reentry missing")
	if scope == "legacy_stabilization":
		check(counts["reasons"].has("stabilization_or_prestige") and counts["kernel_ticks"] > 0, "Stabilization boundary missing")
	if seconds > 0.0 and scale == 1.0 and scope == "isolated":
		check(counts["kernel_ticks"] > 0, "No optimized offline dispatch: " + label)
	for key: String in ["graph", "legacy_graph", "clocks", "result", "trace", "save"]:
		check(native[key] == candidate[key], label + "/" + str(seconds) + "/" + scope + ": " + key + " differs")
	for item: Dictionary in [native, candidate]:
		item["row"]["repeat"] = repeat
		item["row"]["warmup"] = repeat < 0
		item["row"]["instrumented"] = instrument
		rows.append(item["row"])
	print("OFFLINE_PAIR ", label, " ", seconds, " ", scope, " repeat=", repeat, " failures=", failures.size())
	_write()

func _run() -> void:
	var user_error: String = UserScope.rejection()
	if not user_error.is_empty():
		push_error(user_error)
		quit(1)
		return
	loading = load("res://UI/loading_screen.tscn").instantiate()
	root.add_child(loading)
	results_panel = load("res://UI/offline_results_panel.tscn").instantiate()
	root.add_child(results_panel)
	await process_frame
	# Execute the exact source functions without loading the unrelated main
	# game script/editor issue. Source extraction, not an independent formatter.
	var game_source: String = FileAccess.get_file_as_string("res://game.gd")
	var begin: int = game_source.find("func _get_resource_display_name(")
	check(begin >= 0, "Missing production result functions")
	formatter_script = GDScript.new()
	formatter_script.source_code = "extends RefCounted\nvar state: GameState\nvar time_manager: TimeManager\n" + game_source.substr(begin)
	check(formatter_script.reload() == OK, "Production result functions failed to compile")
	var mode: String = OS.get_environment("TM_STUDY_MODE")
	if mode == "smoke":
		await _pair("early", 1.05, "isolated", 1.0, 0.0, true)
	elif mode == "zero":
		await _pair("early", 0.0, "isolated")
		await _pair("early", -1.0, "isolated")
		await _pair("early", 1.05, "fractional_clock", 1.0, 0.0, true)
	elif mode == "boundaries":
		await _pair("critical_greater", 200.0, "isolated", 1.0, 0.0, true)
		await _pair("forge_together", 2.0, "isolated", 1.0, 0.0, true)
		await _pair("starved", 60.0, "isolated", 1.0, 0.0, true)
	elif mode == "confirm":
		for repeat: int in range(-1, 6):
			for label: String in ["early", "forge_competing", "earned_craft_near_completion", "auto_standard"]:
				await _pair(label, 300.0 if label == "auto_standard" else 60.0, "isolated", 1.0, 12.0, false, repeat)
			for scope: String in ["production_logger", "observer"]:
				await _pair("earned_craft_first_craft", 60.0, scope, 1.0, 12.0, false, repeat)
	elif mode == "overhead_variants":
		for repeat: int in range(-1, 6):
			for scope: String in ["isolated", "previous_packet", "per_tick_build", "diagnostic_idle_gate"]:
				await _pair("early", 60.0, scope, 1.0, 12.0, false, repeat)
		await _pair("early", 60.0, "isolated", 1.0, 12.0, false, 0, true)
	elif mode == "bench":
		for repeat: int in range(-1, 3):
			for label: String in ["early", "consumer_50000", "mid", "forge_competing", "reached_multiple", "earned_craft_first_craft", "earned_craft_near_completion", "auto_standard", "earned_feedback", "nexum_relics", "automation", "late_mixed", "diagnostic_multi_buyers", "diagnostic_high_ash"]:
				await _pair(label, 300.0 if label == "auto_standard" else 60.0, "isolated", 1.0, 12.0, false, repeat)
			for scope: String in ["production_logger", "observer"]:
				await _pair("earned_craft_first_craft", 60.0, scope, 1.0, 12.0, false, repeat)
		for duration: float in [600.0, 3600.0, 21600.0, 86400.0]:
			for repeat: int in range(-1, 2 if duration >= 21600.0 else 3):
				await _pair("early", duration, "isolated", 1.0, 12.0, false, repeat)
	else:
		for label: String in ["early", "consumer_50000", "mid", "forge_competing", "earned_craft_near_completion", "auto_standard", "earned_feedback", "nexum_relics", "automation", "late_mixed", "diagnostic_multi_buyers", "diagnostic_high_ash"]:
			await _pair(label, 60.05, "isolated", 1.0, 0.0, true)
		await _pair("early", 1.05, "fractional_clock", 1.0, 0.0, true)
		for scale: float in [0.0, 0.5, 2.0]:
			await _pair("consumer_50000", 1.05, "isolated", scale, 0.0, true)
		for duration: float in [0.0, -1.0, 600.15, 14400.05]:
			await _pair("early", duration, "isolated")
		for scope: String in ["production_logger", "observer"]:
			await _pair("earned_craft_near_completion", 1.05, scope)
		await _pair("consumer_50000", 660.05, "isolated", 1.0, 0.0, true)
		await _pair("consumer_50000", 660.05, "recovery")
		await _pair("consumer_50000", 14400.0, "recovery")
		await _pair("auto_standard", 300.05, "isolated", 1.0, 0.0, true)
		await _pair("early", 181.0, "legacy_stabilization", 1.0, 0.0, true)
		await _pair("automation", 20.05, "frame_mutation", 1.0, 0.0, true)
		await _pair("earned_craft_near_completion", 20.05, "observer_reentry", 1.0, 0.0, true)
		await _pair("early", 60.05, "isolated", 1.0, 12.0, false, 0, true)
	loading.queue_free()
	results_panel.queue_free()
	for failure: String in failures:
		push_error(failure)
	print("OFFLINE_STUDY failures=", failures.size())
	_write()
	quit(0 if failures.is_empty() else 1)

func _write() -> void:
	var file := FileAccess.open("res://tests/experimental/offline_integration_" + OS.get_environment("TM_STUDY_MODE") + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info(), "cpu": OS.get_processor_name(), "rows": rows, "failures": failures}, "\t") + "\n")
