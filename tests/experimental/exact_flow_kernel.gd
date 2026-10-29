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
var observer_instrumentation: bool = false
# Benchmark-owned receivers, including unsupported callbacks, expose local
# observer_calls/observer_usec. These references confer NO admission capability.
var metered_observers: Array[RefCounted] = []
var observer_metrics: Dictionary = {}
var flow_counts: Dictionary = {}
var _running: bool = false
var counters: Dictionary = {"build_usec": 0, "invalidate_usec": 0, "kernel_usec": 0, "fallback_usec": 0, "builds": 0, "kernel_ticks": 0, "fallback_ticks": 0, "event_ticks": 0, "structural_invalidations": 0, "event_check_usec": 0, "reasons": {}, "writeback_usec": 0, "cycle_usec": 0, "cycle_invalidations": 0}


func _init(target: Simulation, events: RefCounted = null) -> void:
	simulation = target
	journal = events


func run(ticks: int, record_trace: bool = false) -> bool:
	if _running or ticks < 0:
		return false
	_running = true
	trace.clear()
	var observer_before: Vector2i = Vector2i.ZERO
	if observer_instrumentation:
		observer_metrics = {"eligible_ticks": 0, "native_fallback_ticks": 0, "fallback_ticks_by_reason": {}, "observer_checks": 0, "observer_signal_checks": 0, "observer_check_usec": 0, "observer_invocations": 0, "callback_usec": 0, "observer_triggered_invalidations": 0, "automation_invalidations": 0, "cycle_invalidations": 0, "automatic_upgrade_invalidations": 0, "packet_rebuilds": 0, "eligibility_usec": 0, "packet_build_usec": 0}
		observer_before = _observer_totals()
	var packet: RefCounted = null
	var unsupported: bool = false
	var fallback_reason: String = ""
	var kernel_ticks: int = 0
	var fallback_ticks: int = 0
	for tick: int in range(ticks):
		if packet == null and not unsupported:
			var started: int = Time.get_ticks_usec()
			packet = Packet.new()
			packet.measure_flows = collect_flow_counters
			packet.measure_cycle_time = measure_phases
			if observer_instrumentation:
				packet.observer_metrics = observer_metrics
			var eligibility_started: int = Time.get_ticks_usec() if observer_instrumentation else 0
			var supported: bool = packet.build(simulation, journal)
			if observer_instrumentation:
				var elapsed: int = Time.get_ticks_usec() - eligibility_started
				observer_metrics["eligibility_usec"] += elapsed
				observer_metrics["packet_build_usec"] += elapsed
				observer_metrics["packet_rebuilds"] += 1
			counters["build_usec"] += Time.get_ticks_usec() - started
			counters["builds"] += 1
			if not supported:
				var reason: String = packet.error
				fallback_reason = reason
				counters["reasons"][reason] = int(counters["reasons"].get(reason, 0)) + 1
				packet = null
				unsupported = true
		var event_started: int = Time.get_ticks_usec() if measure_phases else 0
		var due: bool = packet != null and packet.event_due()
		if measure_phases:
			counters["event_check_usec"] += Time.get_ticks_usec() - event_started
		if due:
			fallback_reason = "automatic_upgrade"
			if observer_instrumentation:
				observer_metrics["automatic_upgrade_invalidations"] += 1
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
			if observer_instrumentation:
				var reasons: Dictionary = observer_metrics["fallback_ticks_by_reason"]
				reasons[fallback_reason] = int(reasons.get(fallback_reason, 0)) + 1
		else:
			packet.step()
			if measure_phases:
				counters["kernel_usec"] += Time.get_ticks_usec() - started
			kernel_ticks += 1
			if packet.configuration_changed:
				if observer_instrumentation:
					observer_metrics["cycle_invalidations"] += packet.cycle_invalidations
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
	if observer_instrumentation:
		observer_metrics["packet_builds"] = observer_metrics["packet_rebuilds"]
		observer_metrics["packet_rebuilds"] = maxi(0, int(observer_metrics["packet_builds"]) - 1)
		observer_metrics["eligible_ticks"] = kernel_ticks
		observer_metrics["native_fallback_ticks"] = fallback_ticks
		var observer_after: Vector2i = _observer_totals()
		observer_metrics["observer_invocations"] = observer_after.x - observer_before.x
		observer_metrics["callback_usec"] = observer_after.y - observer_before.y
	_running = false
	return true


func _observer_totals() -> Vector2i:
	var totals: Vector2i = Vector2i.ZERO
	for receiver: RefCounted in metered_observers:
		totals.x += receiver.observer_calls
		totals.y += receiver.observer_usec
	return totals


func _collect_packet(packet: RefCounted) -> void:
	if packet != null:
		counters["cycle_usec"] += packet.cycle_usec
		counters["cycle_invalidations"] += packet.cycle_invalidations
	if not collect_flow_counters or packet == null:
		return
	for key: String in packet.flow_counts:
		flow_counts[key] = int(flow_counts.get(key, 0)) + int(packet.flow_counts[key])
	var rates: Dictionary = packet.rate_measurements()
	for key: String in rates:
		flow_counts[key] = int(flow_counts.get(key, 0)) + int(rates[key])
