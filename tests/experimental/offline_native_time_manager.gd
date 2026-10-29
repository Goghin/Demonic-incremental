extends TimeManager

# Throughput control: production tick dispatch, loop, yields and finalization
# are inherited unchanged. Only the external timestamp source is controlled.
var fixed_now: float = 2000000000.0
var journal: RefCounted
var packet: RefCounted
var instrument: bool = false
var on_tick: Callable
var packet_script: Script
var rebuild_each_tick: bool = false
var diagnostic_idle_gate: bool = false
var counters: Dictionary = {}

func _init(target: Simulation, sink: RefCounted) -> void:
	super(target)
	journal = sink

func get_current_timestamp() -> float:
	return fixed_now
