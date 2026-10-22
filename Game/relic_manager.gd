class_name RelicManager
extends RefCounted

const RELIC_DEFINITIONS: Dictionary = {
	"cinder_shard": {"display_name": "Cinder Shard", "family": "production", "multiplier": 1.15, "description": "Increases a generator's output by 15%."},
	"clockwork_ember": {"display_name": "Clockwork Ember", "family": "cycle_speed", "multiplier": 1.10, "description": "Increases cycle speed by 10%."},
	"void_lining": {"display_name": "Void Lining", "family": "input_efficiency", "multiplier": 0.90, "description": "Reduces resource input consumption by 10%."}
}

var inventory: Array[Dictionary] = []
var equipped: Dictionary = {}
var _next_instance_number: int = 1

func ensure_starter_relic() -> void:
	for relic in inventory:
		if str(relic.get("definition_id", "")) == "cinder_shard":
			return
	add_relic("cinder_shard")

func add_relic(definition_id: String) -> String:
	if not RELIC_DEFINITIONS.has(definition_id):
		return ""
	var instance_id := "relic_%d" % _next_instance_number
	_next_instance_number += 1
	inventory.append({"instance_id": instance_id, "definition_id": definition_id})
	return instance_id

func get_relic(instance_id: String) -> Dictionary:
	for relic in inventory:
		if str(relic.get("instance_id", "")) == instance_id:
			return relic
	return {}

func get_definition(definition_id: String) -> Dictionary:
	return RELIC_DEFINITIONS.get(definition_id, {})

func get_inventory_options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for relic in inventory:
		var definition := get_definition(str(relic.get("definition_id", "")))
		if definition.is_empty():
			continue
		result.append({
			"instance_id": str(relic.get("instance_id", "")),
			"display_name": str(definition.get("display_name", "Unknown Relic")),
			"description": str(definition.get("description", "")),
			"family": str(definition.get("family", ""))
		})
	return result

func get_equipped_relic_id(generator_id: String, slot_index: int = 0) -> String:
	var generator_slots: Variant = equipped.get(generator_id, {})
	if generator_slots is Dictionary:
		return str(generator_slots.get(str(slot_index), ""))
	# Support callers and in-memory data that still use the legacy shape.
	if slot_index == 0 and generator_slots is String:
		return str(generator_slots)
	return ""


func get_equipped_relic_ids(generator_id: String) -> Array[String]:
	var result: Array[String] = []
	var slot_count: int = 0
	var generator_slots: Variant = equipped.get(generator_id, {})
	if generator_slots is Dictionary:
		slot_count = generator_slots.size()
	elif generator_slots is String and str(generator_slots) != "":
		result.append(str(generator_slots))
		return result
	for slot_index in range(slot_count):
		var instance_id := get_equipped_relic_id(generator_id, slot_index)
		if instance_id != "":
			result.append(instance_id)
	return result


func equip_relic(
	generator_id: String,
	instance_id: String,
	state: GameState,
	slot_index: int = 0
) -> bool:
	if state.get_generator(generator_id) == null or slot_index < 0:
		return false
	var unlocked_slots: int = state.eternal_flame_upgrade_manager.get_relic_slot_count(
		generator_id,
		state.eternal_flame_state
	)
	if slot_index >= unlocked_slots or get_relic(instance_id).is_empty():
		return false

	# A relic instance can occupy only one slot across all generators.
	for equipped_generator_variant in equipped.keys():
		var equipped_generator_id := str(equipped_generator_variant)
		var generator_slots: Variant = equipped[equipped_generator_variant]
		if generator_slots is String:
			if str(generator_slots) == instance_id:
				equipped.erase(equipped_generator_variant)
				break
		elif generator_slots is Dictionary:
			for equipped_slot_key in generator_slots.keys():
				if str(generator_slots[equipped_slot_key]) == instance_id:
					generator_slots.erase(equipped_slot_key)
					if generator_slots.is_empty():
						equipped.erase(equipped_generator_variant)
					break
			if not equipped.has(equipped_generator_variant):
				continue

	var slots: Dictionary = equipped.get(generator_id, {})
	if not slots is Dictionary:
		slots = {"0": str(slots)} if str(slots) != "" else {}
	slots[str(slot_index)] = instance_id
	equipped[generator_id] = slots
	return true


func unequip_relic(generator_id: String, slot_index: int = 0) -> void:
	var slots: Variant = equipped.get(generator_id, {})
	if slots is String:
		if slot_index == 0:
			equipped.erase(generator_id)
		return
	if slots is Dictionary:
		slots.erase(str(slot_index))
		if slots.is_empty():
			equipped.erase(generator_id)
		else:
			equipped[generator_id] = slots

func get_effect_status(definition_id: String, generator_id: String, state: GameState) -> String:
	var definition := get_definition(definition_id)
	var generator: Generator = state.get_generator(generator_id)
	if definition.is_empty() or generator == null:
		return "Inactive"
	match str(definition.get("family", "")):
		"production":
			if generator.get_operation_mode() != null and generator.get_operation_mode().is_resource_transfer:
				return "Inactive in resource-transfer mode"
			return "Active"
		"cycle_speed":
			return "Active" if generator.definition.cycle_based else "Inactive: no cycle"
		"input_efficiency":
			return "Active" if not generator.get_active_inputs().is_empty() else "Inactive: no inputs"
	return "Inactive"

func get_save_data() -> Dictionary:
	return {"inventory": inventory.duplicate(true), "equipped": equipped.duplicate(true), "next_instance_number": _next_instance_number}

func load_save_data(data: Dictionary) -> void:
	inventory.clear()
	equipped.clear()
	_next_instance_number = maxi(1, int(data.get("next_instance_number", 1)))
	var inventory_data: Variant = data.get("inventory", [])
	if inventory_data is Array:
		for entry in inventory_data:
			if not entry is Dictionary:
				continue
			var instance_id := str(entry.get("instance_id", ""))
			var definition_id := str(entry.get("definition_id", ""))
			if instance_id == "" or not RELIC_DEFINITIONS.has(definition_id):
				continue
			inventory.append({"instance_id": instance_id, "definition_id": definition_id})
	var equipped_data: Variant = data.get("equipped", {})
	if equipped_data is Dictionary:
		var claimed_instances: Dictionary = {}
		for generator_id_variant in equipped_data.keys():
			var generator_id := str(generator_id_variant)
			var saved_slots: Variant = equipped_data[generator_id_variant]
			var normalized_slots: Dictionary = {}
			if saved_slots is String:
				# Migrate saves from the original one-relic-per-generator format.
				if str(saved_slots) != "":
					normalized_slots["0"] = str(saved_slots)
			elif saved_slots is Dictionary:
				for slot_key in saved_slots.keys():
					normalized_slots[str(slot_key)] = str(saved_slots[slot_key])
			for slot_key in normalized_slots.keys():
				var instance_id := str(normalized_slots[slot_key])
				if get_relic(instance_id).is_empty() or claimed_instances.has(instance_id):
					normalized_slots.erase(slot_key)
					continue
				if not str(slot_key).is_valid_int() or int(slot_key) < 0:
					normalized_slots.erase(slot_key)
					continue
				claimed_instances[instance_id] = true
			if not normalized_slots.is_empty():
				equipped[generator_id] = normalized_slots
	for relic in inventory:
		var instance_id := str(relic.get("instance_id", ""))
		if instance_id.begins_with("relic_"):
			_next_instance_number = maxi(_next_instance_number, int(instance_id.trim_prefix("relic_")) + 1)
