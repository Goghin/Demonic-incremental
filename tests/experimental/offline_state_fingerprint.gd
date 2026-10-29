extends RefCounted

# Read-only validation, never a checkpoint/restore implementation. All script
# variables and alias topology are encoded; native logger wall stamps alone
# are external observations and omitted by an explicit contract.
var objects: Dictionary = {}
var containers: Array = []

func capture(value: Variant) -> PackedByteArray:
	objects.clear()
	containers.clear()
	return var_to_bytes(_read(value))

func _read(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		for index: int in range(containers.size()):
			if is_same(value, containers[index]):
				return ["container_ref", index]
		var identity: int = containers.size()
		containers.append(value)
		var items: Array = []
		if value is Array:
			for item: Variant in value:
				items.append(_read(item))
		else:
			for key: Variant in value:
				items.append([_read(key), _read(value[key])])
		return ["array" if value is Array else "dictionary", identity, items]
	if value is Object and value != null:
		if value is Script:
			return ["script", value.resource_path]
		var identity: int = value.get_instance_id()
		if objects.has(identity):
			return ["object_ref", objects[identity]]
		var ordinal: int = objects.size()
		objects[identity] = ordinal
		if value is WeakRef:
			return ["weak_reference", ordinal, _read(value.get_ref())]
		if value is RandomNumberGenerator:
			return ["rng", ordinal, value.seed, value.state]
		if value is GameplayLog:
			var events: Array = value.events.duplicate(true)
			for event: Dictionary in events:
				event.erase("timestamp")
				event.erase("unix_time")
			return ["native_log", ordinal, _read(events), value._file_warning_reported]
		var fields: Array = []
		for property: Dictionary in value.get_property_list():
			if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
				continue
			var name: String = property["name"]
			if name == "state" and (value is GeneratorAutomationManager or value is UpgradeAutomationManager or value is UpgradeSystem):
				continue
			fields.append([name, _read(value.get(name))])
		return ["object", ordinal, value.get_class(), value.get_script().resource_path if value.get_script() != null else "", fields]
	if value is Callable:
		return ["callable", value.get_method(), value.get_bound_arguments_count()] if value.is_valid() else ["empty_callable"]
	return value
