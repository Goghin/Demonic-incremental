extends SceneTree

const Runner = preload("res://tests/experimental/horizon_runner.gd")
const Fixtures = preload("res://tests/experimental/horizon_fixtures.gd")
const Checkpoint = preload("res://tests/experimental/continuous_checkpoint.gd")
const Metrics = preload("res://tests/experimental/adaptive_metrics.gd")

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var runner = Runner.new(Simulation.new(Fixtures.make_state("feedback")))
	runner.audit_all_accepted = false
	runner.overrides = {"reuse_probe_fields": false, "ensure_statistics_once": false}
	runner.run(3600.0)
	assert(runner.guard() == "", "Component fixture is not eligible for projection.")
	var saved: Dictionary = Checkpoint.capture(runner.simulation)
	var timings: Dictionary = {"baseline": [], "fields": [], "ensure": []}
	var hashes: Dictionary = {}
	var variants: Array[String] = ["baseline", "fields", "ensure"]
	for repeat_index in range(9):
		for offset in range(3):
			var variant: String = variants[(repeat_index + offset) % 3]
			runner.reuse_probe_fields = variant == "fields"
			runner.ensure_statistics_once = variant == "ensure"
			var elapsed: int = 0
			for _iteration in range(100):
				Checkpoint.restore(runner.simulation, saved)
				var before: int = Time.get_ticks_usec()
				runner._map_advance(60.0, 3660.0)
				elapsed += Time.get_ticks_usec() - before
			timings[variant].append(elapsed)
			hashes[variant] = var_to_bytes([Metrics.numeric(runner.simulation.state), Metrics.discrete(runner.simulation.state), str(runner.simulation.state.gameplay_rng.state)]).hex_encode().sha256_text()
	print("OPERATOR_JSON " + JSON.stringify({"iterations_per_block": 100, "blocks": 9,
		"usec": timings, "hashes": hashes, "exact": hashes["baseline"] == hashes["fields"] and hashes["baseline"] == hashes["ensure"]}))
	quit(0 if hashes["baseline"] == hashes["fields"] and hashes["baseline"] == hashes["ensure"] else 1)
