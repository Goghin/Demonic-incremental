extends RefCounted

const Packet = preload("res://tests/experimental/exact_flow_packet.gd")
const View = preload("res://tests/experimental/exact_flow_view.gd")
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
var simulation: Simulation
var journal: RefCounted
var trace: Array[PackedByteArray] = []
var detailed_trace: bool = false
# Intrusive per-phase clocks are OFF for normal throughput measurements.
var measure_phases: bool = false
var collect_flow_counters: bool = false
var flow_counts: Dictionary = {}
var _running: bool = false
var counters: Dictionary = {"build_usec": 0, "invalidate_usec": 0, "kernel_usec": 0, "fallback_usec": 0, "builds": 0, "kernel_ticks": 0, "fallback_ticks": 0, "event_ticks": 0, "structural_invalidations": 0, "event_check_usec": 0, "reasons": {}, "writeback_usec": 0}


func _init(target: Simulation, events: RefCounted = null) -> void:
	simulation = target
	journal = events


func run(ticks: int, record_trace: bool = false) -> bool:
	if _running or ticks < 0:
		return false
	_running = true
	trace.clear()
	var packet: RefCounted = null
	var unsupported: bool = false
	var kernel_ticks: int = 0
	var fallback_ticks: int = 0
	for tick: int in range(ticks):
		if packet == null and not unsupported:
			var started: int = Time.get_ticks_usec()
			packet = Packet.new()
			packet.measure_flows = collect_flow_counters
			var supported: bool = packet.build(simulation, journal)
			counters["build_usec"] += Time.get_ticks_usec() - started
			counters["builds"] += 1
			if not supported:
				var reason: String = packet.error
				counters["reasons"][reason] = int(counters["reasons"].get(reason, 0)) + 1
				packet = null
				unsupported = true
		var event_started: int = Time.get_ticks_usec() if measure_phases else 0
		var due: bool = packet != null and packet.event_due()
		if measure_phases:
			counters["event_check_usec"] += Time.get_ticks_usec() - event_started
		if due:
			var started: int = Time.get_ticks_usec()
			_collect_packet(packet)
			packet = null
			counters["invalidate_usec"] += Time.get_ticks_usec() - started
			counters["event_ticks"] += 1
		var started: int = Time.get_ticks_usec() if measure_phases else 0
		if packet == null:
			simulation.update(STEP, true)
			if measure_phases:
				counters["fallback_usec"] += Time.get_ticks_usec() - started
			fallback_ticks += 1
		else:
			packet.step()
			if measure_phases:
				counters["kernel_usec"] += Time.get_ticks_usec() - started
			kernel_ticks += 1
			if packet.configuration_changed:
				var invalidation_started: int = Time.get_ticks_usec()
				_collect_packet(packet)
				packet = null
				counters["structural_invalidations"] += 1
				counters["invalidate_usec"] += Time.get_ticks_usec() - invalidation_started
		if record_trace:
			trace.append(View.capture(simulation, journal, detailed_trace))
	# No cached coefficient/reference survives an external synchronization point.
	var started: int = Time.get_ticks_usec()
	_collect_packet(packet)
	packet = null
	counters["invalidate_usec"] += Time.get_ticks_usec() - started
	counters["kernel_ticks"] += kernel_ticks
	counters["fallback_ticks"] += fallback_ticks
	_running = false
	return true


func _collect_packet(packet: RefCounted) -> void:
	if not collect_flow_counters or packet == null:
		return
	for key: String in packet.flow_counts:
		flow_counts[key] = int(flow_counts.get(key, 0)) + int(packet.flow_counts[key])
