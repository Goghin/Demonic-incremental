extends RefCounted

const Events = preload("res://tests/experimental/transaction_events.gd")
const Sink = preload("res://tests/experimental/observer_readonly_sink.gd")

# Called at packet admission, never per tick. Every accepted method is reviewed
# code with scalar arguments and collector-local writes only. Exact script
# identity excludes subclasses/overrides. Deferred, one-shot, bound, unbound,
# built-in and arbitrary callbacks remain native. There is no public trust API.
static func rejection(target: Simulation, journal: RefCounted, metrics: Dictionary) -> String:
	var started: int = Time.get_ticks_usec() if not metrics.is_empty() else 0
	var result: String = ""
	for signal_info: Dictionary in target.get_signal_list():
		if not metrics.is_empty():
			metrics["observer_signal_checks"] += 1
		for connection: Dictionary in target.get_signal_connection_list(signal_info["name"]):
			if not metrics.is_empty():
				metrics["observer_checks"] += 1
			var callback: Callable = connection["callable"]
			var receiver: Object = callback.get_object()
			if receiver == null or not ((receiver == journal and receiver.get_script() == Events) or receiver.get_script() == Sink) or callback.get_method() != signal_info["name"] or callback.get_bound_arguments_count() != 0 or callback.get_unbound_arguments_count() != 0 or int(connection["flags"]) != 0:
				result = "external_observer"
				break
		if not result.is_empty():
			break
	if not metrics.is_empty():
		metrics["observer_check_usec"] += Time.get_ticks_usec() - started
	return result
