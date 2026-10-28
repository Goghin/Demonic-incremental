extends RefCounted

# Experimental, synchronous, isolated Simulation.update(..., true) only.
# Captures script fields as a graph, not Object.duplicate() or save/load.
# Containers and objects retain their original identities and alias topology.
const Events = preload("res://tests/experimental/transaction_events.gd")
var journal: RefCounted
var error: String = ""
var records: Array[Dictionary] = []
var objects: Dictionary = {}
var containers: Array = []
var container_ids: Array[int] = []


func capture(simulation: Simulation, event_journal: RefCounted = null) -> bool:
	journal = event_journal
	error = ""
	records.clear()
	objects.clear()
	containers.clear()
	container_ids.clear()
	if journal != null:
		_encode(journal)
	_encode(simulation)
	if simulation.state.gameplay_log == null or simulation.state.gameplay_log.get_script() != preload("res://tests/experimental/autobuyer_fixtures.gd").TickLog:
		error = "The isolated TickLog gameplay event sink is required"
	if simulation.profiling_enabled:
		error = "Wall-clock profiling is outside deterministic transaction scope"
	return error.is_empty()


func _encode(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		for index: int in range(containers.size()):
			if is_same(value, containers[index]):
				return {"ref": container_ids[index]}
		var id: int = records.size()
		containers.append(value)
		container_ids.append(id)
		records.append({"kind": "array" if value is Array else "dictionary", "target": value, "items": []})
		var items: Array = []
		if value is Array:
			for item: Variant in value:
				items.append(_encode(item))
		else:
			for key: Variant in value:
				items.append([_encode(key), _encode(value[key])])
		records[id]["items"] = items
		return {"ref": id}
	if value is Object:
		if value == null:
			return null
		if value is Script or value is RealmLayout:
			return {"literal": value}
		var instance_id: int = value.get_instance_id()
		if objects.has(instance_id):
			return {"ref": objects[instance_id]}
		var id: int = records.size()
		objects[instance_id] = id
		records.append({"kind": "object", "target": value, "fields": {}})
		var fields: Dictionary = {}
		if value is RandomNumberGenerator:
			# seed must be restored before state: assigning seed resets state.
			fields = {"seed": value.seed, "state": value.state}
		elif value is WeakRef:
			# Weak back-references are immutable during supported advancement.
			records[id]["kind"] = "weak"
		elif value is RefCounted and value.get_script() != null:
			var path: String = value.get_script().resource_path
			if not _supported_script(path) and value.get_script() != preload("res://tests/experimental/autobuyer_fixtures.gd").TickLog:
				error = "Unsupported script: " + path
				return {"ref": id}
			for signal_info: Dictionary in value.get_signal_list():
				for connection: Dictionary in value.get_signal_connection_list(signal_info["name"]):
					var callback: Callable = connection["callable"]
					if not (value is Simulation and journal != null and journal.get_script() == Events and callback.get_object() == journal and callback.get_method() == signal_info["name"] and callback.get_bound_arguments_count() == 0 and callback.get_unbound_arguments_count() == 0 and int(connection["flags"]) == 0):
						error = "Connected signal is outside isolated transaction scope: " + path + ":" + str(signal_info["name"])
			for property: Dictionary in value.get_property_list():
				if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
					continue
				var name: String = property["name"]
				# Computed manager alias; _state_ref is the actual ownership field.
				if name == "state" and (value is GeneratorAutomationManager or value is UpgradeAutomationManager or value is UpgradeSystem):
					continue
				fields[name] = _encode(value.get(name))
		else:
			error = "Unsupported native object: " + value.get_class()
		records[id]["fields"] = fields
		return {"ref": id}
	if typeof(value) in [TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY]:
		error = "Packed array requires a dedicated ownership adapter"
	if value is Callable and value.is_valid():
		error = "Callable may escape checkpoint ownership"
	if value is Signal:
		error = "Signal value may escape checkpoint ownership"
	return {"literal": value}


func _supported_script(path: String) -> bool:
	# Explicit audited owner scripts. New subclasses require a scope review.
	return path in [
		"res://Game/AchievementManager.gd",
		"res://Game/GeneratorAutomationManager.gd",
		"res://Game/UpgradeAutomationManager.gd",
		"res://Game/eternal_flame_state.gd",
		"res://Game/eternal_flame_upgrade.gd",
		"res://Game/eternal_flame_upgrade_manager.gd",
		"res://Game/modifier.gd",
		"res://Game/modifiersensitivity.gd",
		"res://Game/realm_configuration.gd",
		"res://Game/realm_effects.gd",
		"res://Game/relic_generation_manager.gd",
		"res://Game/relic_manager.gd",
		"res://Game/requirement.gd",
		"res://Game/resource_statistics.gd",
		"res://Generators/generator.gd",
		"res://Generators/generator_definition.gd",
		"res://Generators/generator_io.gd",
		"res://Generators/generator_operation_mode.gd",
		"res://Resources/GameResource.gd",
		"res://Resources/resource_state.gd",
		"res://Upgrades/UpgradeSystem.gd",
		"res://Upgrades/upgrade.gd",
		"res://Upgrades/upgrade_definition.gd",
		"res://Upgrades/upgrade_effect.gd",
		"res://Upgrades/upgrade_group_definition.gd",
		"res://game_state.gd",
		"res://simulation/simulation.gd",
		"res://tests/experimental/transaction_events.gd",
	]


func _decode(value: Variant) -> Variant:
	if value == null:
		return null
	return records[int(value["ref"])]["target"] if value.has("ref") else value["literal"]


func restore() -> void:
	# All references refer to retained originals, even when candidate code has
	# cleared/replaced a collection or generated new modifiers/inventory entries.
	for record: Dictionary in records:
		var target: Variant = record["target"]
		match record["kind"]:
			"array":
				target.clear()
				for item: Variant in record["items"]:
					target.append(_decode(item))
			"dictionary":
				target.clear()
				for pair: Array in record["items"]:
					target[_decode(pair[0])] = _decode(pair[1])
			"object":
				for name: String in record["fields"]:
					target.set(name, record["fields"][name] if target is RandomNumberGenerator else _decode(record["fields"][name]))


func matches() -> bool:
	for record: Dictionary in records:
		var target: Variant = record["target"]
		match record["kind"]:
			"object":
				for name: String in record["fields"]:
					var expected: Variant = record["fields"][name] if target is RandomNumberGenerator else _decode(record["fields"][name])
					if not is_same(target.get(name), expected):
						return false
			"array":
				if target.size() != record["items"].size():
					return false
				for index: int in range(target.size()):
					if not is_same(target[index], _decode(record["items"][index])):
						return false
			"dictionary":
				if target.size() != record["items"].size():
					return false
				for pair: Array in record["items"]:
					var key: Variant = _decode(pair[0])
					if not target.has(key) or not is_same(target[key], _decode(pair[1])):
						return false
	return true


func describe() -> Dictionary:
	var result: Dictionary = {}
	for record: Dictionary in records:
		if record["kind"] not in ["object", "weak"]:
			continue
		var target: Object = record["target"]
		var owner: String = target.get_script().resource_path if target.get_script() != null else target.get_class()
		if owner == "":
			owner = "autobuyer_fixtures.gd::TickLog"
		if not result.has(owner):
			result[owner] = {"fields": record["fields"].keys(), "instances": 0}
		result[owner]["instances"] += 1
	return result
