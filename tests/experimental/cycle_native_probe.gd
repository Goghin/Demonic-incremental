extends Simulation

# Intrusive diagnostic only; this subclass is never admitted to the kernel.
var metrics: Dictionary = {"cycle_calls": 0, "cycle_usec": 0, "completion_usec": 0, "completions": 0, "auto_attempts": 0, "auto_successes": 0, "downlevels": 0, "completion_level_changes": 0, "startup_level_changes": 0}


func update_cycle_generator(generator: Generator, delta: float, offline_mode: bool = false, heat_upgrade_multiplier: float = -1.0) -> void:
	if generator.definition.id != "infernal_forge":
		super(generator, delta, offline_mode, heat_upgrade_multiplier)
		return
	var previous_level: int = generator.level
	var previous_completions: int = int(metrics["completions"])
	var started: int = Time.get_ticks_usec()
	super(generator, delta, offline_mode, heat_upgrade_multiplier)
	if generator.level != previous_level:
		metrics["completion_level_changes" if int(metrics["completions"]) > previous_completions else "startup_level_changes"] += 1
	metrics["cycle_calls"] += 1
	metrics["cycle_usec"] += Time.get_ticks_usec() - started


func complete_cycle(generator: Generator) -> void:
	var level: int = generator.level
	var started: int = Time.get_ticks_usec()
	super(generator)
	metrics["completions"] += 1
	metrics["completion_usec"] += Time.get_ticks_usec() - started
	if generator.level < level:
		metrics["downlevels"] += 1


func buy_generator(id: String, source: String = "manual") -> bool:
	var result: bool = super(id, source)
	if source == "cycle_auto_run":
		metrics["auto_attempts"] += 1
		if result:
			metrics["auto_successes"] += 1
	return result
