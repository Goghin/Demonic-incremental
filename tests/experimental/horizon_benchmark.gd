extends SceneTree

const Runner = preload("res://tests/experimental/horizon_runner.gd")
const Fixtures = preload("res://tests/experimental/horizon_fixtures.gd")
const Metrics = preload("res://tests/experimental/adaptive_metrics.gd")
const Observer = preload("res://tests/experimental/adaptive_tests.gd")

func _initialize() -> void:
	call_deferred("_run")


func _options() -> Dictionary:
	var result: Dictionary = {"scenario": "feedback", "duration": "600", "accuracy": "balanced",
		"action": "paired", "variant": "normal", "diagnostics": "false", "audit": "dense", "candidate": "default"}
	for argument in OS.get_cmdline_user_args():
		var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			result[pair[0]] = pair[1]
	return result


static func production_digest(path: String = "res://") -> String:
	var directory := DirAccess.open(path)
	if directory == null:
		return "unreadable:" + path
	var entries: Array[String] = []
	for child in directory.get_directories():
		if child.begins_with(".") or path.path_join(child) == "res://tests":
			continue
		entries.append(child + "/" + production_digest(path.path_join(child)))
	for child in directory.get_files():
		if child.get_extension() == "gd" or child == "project.godot":
			entries.append(child + ":" + FileAccess.get_file_as_string(path.path_join(child)).sha256_text())
	entries.sort()
	return "\n".join(entries).sha256_text()


static func header(options: Dictionary, state: GameState) -> Dictionary:
	var sources: Dictionary = {}
	for path in ["simulation/simulation.gd", "Game/time_manager.gd", "game_state.gd", "Generators/generator.gd",
		"Game/modifier.gd", "Game/modifiersensitivity.gd", "Game/resource_statistics.gd", "Game/prestige_system.gd",
		"Game/gameplay_random.gd", "Game/save_manager.gd", "Upgrades/UpgradeRegistry.gd",
		"tests/experimental/horizon_benchmark.gd", "tests/experimental/adaptive_benchmark.gd", "tests/experimental/horizon_fixtures.gd", "tests/experimental/adaptive_tests.gd"]:
		if FileAccess.file_exists("res://" + path):
			sources[path] = FileAccess.get_file_as_string("res://" + path).sha256_text()
	return {"schema": 3, "production_digest": production_digest(), "platform": OS.get_name(), "architecture": {"x86_64": OS.has_feature("x86_64"), "arm64": OS.has_feature("arm64"), "double": OS.has_feature("double")}, "engine": Engine.get_version_info()["string"], "sources": sources,
		"duration": float(options["duration"]), "scenario": options["scenario"], "variant": options["variant"],
		"initial": (Metrics.discrete(state) + JSON.stringify(Metrics.numeric(state)) + str(state.gameplay_rng.state)).sha256_text()}


static func sample(state: GameState, manager: TimeManager) -> Dictionary:
	return {"numeric": Metrics.numeric(state, manager), "discrete": Metrics.discrete(state),
		"rng": str(state.gameplay_rng.state), "prestige": PrestigeSystem.new().calculate_eternal_flame_gain(state)}


static func store_cache(path: String, data: Dictionary) -> void:
	if path == "":
		return
	var file := FileAccess.open(path + ".partial", FileAccess.WRITE)
	assert(file != null, "Cannot write reference trace.")
	file.store_var(data)
	file.close()
	assert(DirAccess.rename_absolute(path + ".partial", path) == OK, "Cannot commit reference trace.")


func _reference(options: Dictionary, wanted: Dictionary = {}) -> Dictionary:
	var state: GameState = Fixtures.make_state(options["scenario"], options["variant"])
	var identity: Dictionary = header(options, state)
	var cache_path: String = options.get("cache", "")
	if FileAccess.file_exists(cache_path) and options.get("refresh_reference", "false") != "true":
		var file := FileAccess.open(cache_path, FileAccess.READ)
		var cached: Variant = file.get_var(false)
		if not cached is Dictionary or cached.get("header", {}) != identity:
			return {"error": "Reference cache does not match sources/engine/fixture/duration."}
		var covers_requested: bool = true
		for tick in wanted:
			covers_requested = covers_requested and cached["samples"].has(tick)
		if covers_requested and cached.get("complete", false):
			cached["reused"] = true
			return cached
		# Recompute the oracle if a denser audit is requested, keeping the
		# union of previously captured times. This is not save-state resumption.
		wanted = wanted.duplicate()
		for tick in cached["samples"]:
			wanted[tick] = true
	var simulation := Simulation.new(state)
	Observer.new().observe(simulation)
	var manager := TimeManager.new(simulation)
	state.simulation_statistics = manager.simulation_statistics
	var seconds: float = float(options["duration"])
	var data: Dictionary = {"header": identity, "samples": {}, "segments": [], "complete": false, "evaluations": 0}
	var start: int = Time.get_ticks_usec()
	var segment_start: int = start
	var audit_usec: int = 0
	var io_usec: int = 0
	var segment_audit: int = 0
	var elapsed: float = 0.0
	for tick in range(ceili(seconds / 0.1)):
		var delta: float = minf(0.1, seconds - elapsed)
		elapsed = minf(seconds, elapsed + delta)
		manager.game_time += delta
		manager.offline_time += delta
		manager.prestige_time += delta
		manager.current_offline_duration += delta
		state.set_lava_mite_dormancy_penalty(manager.get_dormancy_penalty(elapsed))
		simulation.update(delta, true)
		data["evaluations"] += 1
		if (tick + 1) % 600 == 0 or wanted.has(tick + 1) or tick + 1 == ceili(seconds / 0.1):
			var before: int = Time.get_ticks_usec()
			data["samples"][tick + 1] = sample(state, manager)
			audit_usec += Time.get_ticks_usec() - before
		if (tick + 1) % 36000 == 0 or tick + 1 == ceili(seconds / 0.1):
			var now: int = Time.get_ticks_usec()
			data["segments"].append({"until": elapsed, "wall_seconds": float(now - segment_start) / 1e6,
				"compute_seconds": float(now - segment_start - (audit_usec - segment_audit)) / 1e6,
				"numeric": Metrics.numeric(state, manager)})
			data["covered_seconds"] = elapsed
			data["compute_seconds"] = float(now - start - audit_usec - io_usec) / 1e6
			print("REFERENCE_SEGMENT " + JSON.stringify(data["segments"][-1]))
			store_cache(cache_path, data)
			io_usec += Time.get_ticks_usec() - now
			segment_start = Time.get_ticks_usec()
			segment_audit = audit_usec
	data["compute_seconds"] = float(Time.get_ticks_usec() - start - audit_usec - io_usec) / 1e6
	data["wall_seconds"] = float(Time.get_ticks_usec() - start) / 1e6
	data["audit_usec"] = audit_usec
	data["cache_io_usec"] = io_usec
	data["complete"] = true
	data["final"] = sample(state, manager)
	store_cache(cache_path, data)
	return data


func _run() -> void:
	var options: Dictionary = _options()
	if (not Fixtures.SCENARIOS.has(options["scenario"]) and not options["scenario"] in ["mixed", "reward_boundary", "late_feedback"]) or not options["action"] in ["paired", "reference", "adaptive"] or not options["audit"] in ["dense", "fixed"] or not options["candidate"] in ["default", "baseline", "fields", "ensure", "combined"] or not options["variant"] in ["normal", "threshold", "high"] or not str(options["duration"]).is_valid_float() or not is_finite(float(options["duration"])) or float(options["duration"]) < 0.0:
		print("HORIZON_JSON " + JSON.stringify({"complete": false, "error": "Invalid experiment options."}))
		quit(1)
		return
	if options["action"] == "reference":
		var reference: Dictionary = _reference(options)
		if reference.has("error"):
			print("HORIZON_JSON " + JSON.stringify({"phase": "reference", "complete": false, "error": reference["error"]}))
			quit(1)
			return
		print("HORIZON_JSON " + JSON.stringify({"phase": "reference", "complete": reference["complete"],
			"seconds": reference["compute_seconds"], "evaluations": reference["evaluations"]}))
		quit()
		return
	var state: GameState = Fixtures.make_state(options["scenario"], options["variant"])
	var initial: Dictionary = header(options, state)
	var runner = Runner.new(Simulation.new(state))
	Observer.new().observe(runner.simulation)
	runner.accuracy_mode = options["accuracy"]
	runner.audit_all_accepted = options["audit"] == "dense"
	runner.diagnostics = options["diagnostics"] == "true"
	runner.segment_seconds = float(options.get("segment", "3600"))
	runner.segment_callback = func(record: Dictionary) -> void: print("ADAPTIVE_SEGMENT " + JSON.stringify(record))
	var candidates: Dictionary = {
		"baseline": {"reuse_probe_fields": false, "ensure_statistics_once": false},
		"fields": {"reuse_probe_fields": true, "ensure_statistics_once": false},
		"ensure": {"reuse_probe_fields": false, "ensure_statistics_once": true},
		"combined": {"reuse_probe_fields": true, "ensure_statistics_once": true}}
	if candidates.has(options["candidate"]):
		runner.overrides = candidates[options["candidate"]].duplicate(true)
	if options.has("margin_proof"):
		runner.overrides["monotone_decay_margin"] = options["margin_proof"] == "true"
	if options.has("short_exact"):
		runner.overrides["short_exact_seconds"] = float(options["short_exact"])
	var before: int = Time.get_ticks_usec()
	var counters: Dictionary = runner.run(float(options["duration"]))
	var wall: float = float(Time.get_ticks_usec() - before) / 1e6
	var final: Dictionary = sample(state, runner.manager)
	var event_counts: Dictionary = {}
	for event in state.gameplay_log.events:
		var key: String = str(event["event"])
		if key == "craft":
			key += "/critical" if event["details"].get("critical", false) else "/normal"
		event_counts[key] = int(event_counts.get(key, 0)) + 1
	var result: Dictionary = {"phase": "adaptive", "event_counts": event_counts, "options": options, "initial": initial,
		"seconds": wall, "counters": counters, "segments": runner.segments,
		"final": final, "complete": counters.get("strict_failure", "") == "", "samples": runner.samples.size(),
		"sources": {"runner": FileAccess.get_file_as_string("res://tests/experimental/horizon_runner.gd").sha256_text(),
			"modes": FileAccess.get_file_as_string("res://tests/experimental/accuracy_modes.gd").sha256_text(),
			"base": FileAccess.get_file_as_string("res://tests/experimental/adaptive_offline.gd").sha256_text(),
			"feedback": FileAccess.get_file_as_string("res://tests/experimental/feedback_offline.gd").sha256_text()}}
	print("ADAPTIVE_COMPLETE " + JSON.stringify({"seconds": wall, "counters": counters}))
	if not result["complete"]:
		print("HORIZON_JSON " + JSON.stringify(result))
		quit(1)
		return
	if options["action"] != "adaptive":
		var reference: Dictionary = _reference(options, runner.samples if runner.audit_all_accepted else {})
		if reference.has("error") or reference.get("header", {}) != initial:
			result["complete"] = false
			result["error"] = reference.get("error", "Adaptive/reference initial states differ.")
			print("HORIZON_JSON " + JSON.stringify(result))
			quit(1)
			return
		result["reference_complete"] = reference["complete"]
		result["reference_reused"] = reference.get("reused", false)
		result["reference_seconds"] = reference["compute_seconds"]
		result["speedup"] = float(reference["compute_seconds"]) / maxf(wall, 1e-9)
		result["maximum_deviation"] = {"resource_abs": 0.0, "resource_rel": 0.0,
			"statistics_abs": 0.0, "statistics_rel": 0.0, "normalized": 0.0}
		result["discrete_parity"] = true
		result["rng_parity"] = true
		result["prestige_parity"] = true
		var audits: int = 0
		for tick in runner.samples:
			if not reference["samples"].has(tick):
				continue
			var actual: Dictionary = runner.samples[tick]
			var expected: Dictionary = reference["samples"][tick]
			var error: Dictionary = Metrics.compare(expected["numeric"], actual["numeric"], runner.absolute_tolerance, runner.relative_tolerance)
			for key in result["maximum_deviation"]:
				result["maximum_deviation"][key] = maxf(float(result["maximum_deviation"][key]), float(error[key]))
			result["discrete_parity"] = result["discrete_parity"] and actual["discrete"] == expected["discrete"]
			result["rng_parity"] = result["rng_parity"] and actual["rng"] == expected["rng"]
			# The reference reward is included in the discrete fingerprint too.
			result["prestige_parity"] = result["prestige_parity"] and actual["prestige"] == expected["prestige"]
			audits += 1
		result["audits"] = audits
		result["reference_final"] = reference.get("final", {})
		result["comparison_coverage_seconds"] = reference.get("covered_seconds", 0.0)
		if reference["complete"]:
			result["final_deviation"] = Metrics.compare(reference["final"]["numeric"], final["numeric"], runner.absolute_tolerance, runner.relative_tolerance)
			result["discrete_parity"] = result["discrete_parity"] and reference["final"]["discrete"] == final["discrete"]
			result["rng_parity"] = result["rng_parity"] and reference["final"]["rng"] == final["rng"]
			result["prestige_parity"] = result["prestige_parity"] and reference["final"]["prestige"] == final["prestige"]
			result["exact_numeric_parity"] = var_to_bytes(reference["final"]["numeric"]) == var_to_bytes(final["numeric"])
			result["accuracy_pass"] = float(result["maximum_deviation"]["normalized"]) <= 1.0 and float(result["final_deviation"]["normalized"]) <= 1.0
		else:
			result["accuracy_pass"] = false # An incomplete oracle never counts as a pass.
	print("HORIZON_JSON " + JSON.stringify(result))
	quit()
