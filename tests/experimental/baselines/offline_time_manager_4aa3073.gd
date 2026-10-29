extends TimeManager

# Feasibility only. Native coordinator retains every real/game clock update,
# partial step, dormancy calculation, frame yield, progress event and finalizer.
const Packet = preload("res://tests/experimental/baselines/exact_flow_4aa3073_packet.gd")
var packet_script: Script = Packet
var rebuild_each_tick: bool = false
var diagnostic_idle_gate: bool = false
var accelerated: bool = false
var instrument: bool = false
var fixed_now: float = 2000000000.0
var journal: RefCounted
var packet: RefCounted
var rejected: bool = false
var counters: Dictionary = {"builds": 0, "build_usec": 0, "kernel_ticks": 0, "fallback_ticks": 0, "partial_ticks": 0, "structural_invalidations": 0, "event_invalidations": 0, "progress_boundaries": 0, "dispatch_usec": 0, "reasons": {}}
var on_tick: Callable


func _init(target: Simulation, sink: RefCounted = null, use_kernel: bool = false) -> void:
	super(target)
	journal = sink
	accelerated = use_kernel
	offline_simulation_progress.connect(_boundary)


func get_current_timestamp() -> float:
	return fixed_now


func _boundary(_current: int, _total: int) -> void:
	# Called before the native await, including final progress. A frame can
	# execute arbitrary callbacks, so no configuration survives it.
	packet = null
	rejected = false
	counters["progress_boundaries"] += 1


func _advance_offline_step(game_seconds: float) -> void:
	var started: int = Time.get_ticks_usec() if instrument else 0
	if not accelerated:
		super(game_seconds)
	else:
		if stabilization_countdown_active or simulation.state.prestige_planning:
			packet = null
			if not rejected:
				counters["reasons"]["stabilization_or_prestige"] = int(counters["reasons"].get("stabilization_or_prestige", 0)) + 1
			rejected = true
		if game_seconds != OFFLINE_MAX_GAME_STEP:
			packet = null
			rejected = false
			counters["partial_ticks"] += 1
		elif packet == null and not rejected:
			var build_started: int = Time.get_ticks_usec()
			packet = packet_script.new()
			counters["builds"] += 1
			if not packet.build(simulation, journal):
				var reason: String = packet.error
				counters["reasons"][reason] = int(counters["reasons"].get(reason, 0)) + 1
				packet = null
				rejected = true
			if packet != null and diagnostic_idle_gate:
				# Controlled no-automation/no-external-start diagnostic only.
				assert(not preload("res://tests/experimental/exact_flow_automation.gd").enabled(simulation.state))
				for machine: RefCounted in packet.machines:
					if machine.cycle_based and not machine.generator.cycle_active and not machine.generator.auto_run_cycles:
						machine.native_cycle = false
			counters["build_usec"] += Time.get_ticks_usec() - build_started
		if packet != null and packet.event_due():
			packet = null
			counters["event_invalidations"] += 1
		if packet == null:
			super(game_seconds)
			counters["fallback_ticks"] += 1
		else:
			packet.step()
			# Same association and position as native _advance_offline_step.
			game_time += game_seconds
			counters["kernel_ticks"] += 1
			if packet.configuration_changed:
				packet = null
				counters["structural_invalidations"] += 1
	if rebuild_each_tick:
		packet = null
		rejected = false
	if instrument:
		counters["dispatch_usec"] += Time.get_ticks_usec() - started
	if on_tick.is_valid():
		on_tick.call(self)
