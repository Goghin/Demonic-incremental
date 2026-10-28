extends RefCounted

const Descriptors = preload("res://tests/experimental/runtime_state_descriptors.gd")
const Events = preload("res://tests/experimental/transaction_events.gd")
enum Kind { OBJECT, ARRAY, DICTIONARY, WEAK }
var journal: RefCounted
var error: String = ""
var targets: Array = []
var kinds: Array[int] = []
var fields: Array = []
var values: Array = []
var links: Array = []
var _objects: Dictionary = {}
var _container_buckets: Dictionary = {}


func capture(simulation: Simulation, event_journal: RefCounted = null) -> bool:
	journal = event_journal
	error = ""
	targets.clear()
	kinds.clear()
	fields.clear()
	values.clear()
	links.clear()
	_objects.clear()
	_container_buckets.clear()
	if journal != null:
		_intern(journal)
	_intern(simulation)
	if simulation.state.gameplay_log == null or simulation.state.gameplay_log.get_script() != preload("res://tests/experimental/autobuyer_fixtures.gd").TickLog:
		error = "The isolated TickLog gameplay event sink is required"
	if simulation.profiling_enabled:
		error = "Wall-clock profiling is outside deterministic transaction scope"
	return error.is_empty()


func _intern(value: Variant) -> int:
	var bucket: Array = []
	if value is Array or value is Dictionary:
		# Identity is still checked explicitly. Type and size only narrow the
		# candidates; equal contents never imply aliasing. Capture is synchronous.
		var type_id: int = typeof(value)
		if not _container_buckets.has(type_id):
			_container_buckets[type_id] = {}
		var sizes: Dictionary = _container_buckets[type_id]
		if not sizes.has(value.size()):
			sizes[value.size()] = []
		bucket = sizes[value.size()]
		for previous: int in bucket:
			if is_same(value, targets[previous]):
				return previous
	elif value is Object:
		if _objects.has(value.get_instance_id()):
			return _objects[value.get_instance_id()]
	else:
		error = "Graph record requires an object or container"
		return -1
	var id: int = targets.size()
	var data: Array = []
	var refs: Array[int] = []
	targets.append(value)
	kinds.append(Kind.OBJECT)
	fields.append([])
	values.append(data)
	links.append(refs)
	if value is Array or value is Dictionary:
		bucket.append(id)
		if value is Array:
			kinds[id] = Kind.ARRAY
			for item: Variant in value:
				_store(item, data, refs)
		else:
			kinds[id] = Kind.DICTIONARY
			for key: Variant in value:
				_store(key, data, refs)
				_store(value[key], data, refs)
	else:
		_objects[value.get_instance_id()] = id
		if value is RandomNumberGenerator:
			fields[id] = ["seed", "state"]
			_store(value.seed, data, refs)
			_store(value.state, data, refs)
		elif value is WeakRef:
			kinds[id] = Kind.WEAK
		elif value is RefCounted and Descriptors.supports(value):
			fields[id] = Descriptors.fields_for(value)
			for signal_info: Dictionary in value.get_signal_list():
				for connection: Dictionary in value.get_signal_connection_list(signal_info["name"]):
					var callback: Callable = connection["callable"]
					if not (value is Simulation and journal != null and journal.get_script() == Events and callback.get_object() == journal and callback.get_method() == signal_info["name"] and callback.get_bound_arguments_count() == 0 and callback.get_unbound_arguments_count() == 0 and int(connection["flags"]) == 0):
						error = "Connected signal is outside isolated transaction scope"
			for name: String in fields[id]:
				_store(value.get(name), data, refs)
		else:
			error = "Unsupported object or descriptor schema: " + value.get_class()
	return id


func _store(value: Variant, data: Array, refs: Array[int]) -> void:
	if value is Array or value is Dictionary or (value is Object and value != null and not value is Script and not value is RealmLayout):
		refs.append(_intern(value))
		data.append(null)
		return
	if typeof(value) in [TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY]:
		error = "Packed array requires a dedicated ownership adapter"
	if value is Callable and value.is_valid():
		error = "Callable may escape checkpoint ownership"
	if value is Signal:
		error = "Signal value may escape checkpoint ownership"
	refs.append(-1)
	data.append(value)


func _value(id: int, index: int) -> Variant:
	var ref_id: int = links[id][index]
	return targets[ref_id] if ref_id >= 0 else values[id][index]


func restore() -> void:
	for id: int in range(targets.size()):
		var target: Variant = targets[id]
		match kinds[id]:
			Kind.OBJECT:
				for index: int in range(fields[id].size()):
					target.set(fields[id][index], _value(id, index))
			Kind.ARRAY:
				target.clear()
				for index: int in range(values[id].size()):
					target.append(_value(id, index))
			Kind.DICTIONARY:
				target.clear()
				for index: int in range(0, values[id].size(), 2):
					target[_value(id, index)] = _value(id, index + 1)


func matches() -> bool:
	for id: int in range(targets.size()):
		var target: Variant = targets[id]
		match kinds[id]:
			Kind.OBJECT:
				for index: int in range(fields[id].size()):
					if not is_same(target.get(fields[id][index]), _value(id, index)):
						return false
			Kind.ARRAY:
				if target.size() != values[id].size():
					return false
				for index: int in range(values[id].size()):
					if not is_same(target[index], _value(id, index)):
						return false
			Kind.DICTIONARY:
				if target.size() * 2 != values[id].size():
					return false
				for index: int in range(0, values[id].size(), 2):
					var key: Variant = _value(id, index)
					if not target.has(key) or not is_same(target[key], _value(id, index + 1)):
						return false
	return true
