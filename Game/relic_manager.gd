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

func get_equipped_relic_id(generator_id: String) -> String:
	return str(equipped.get(generator_id, ""))

func equip_relic(generator_id: String, instance_id: String, state: GameState) -> bool:
	if state.get_generator(generator_id) == null:
		return false
	if state.eternal_flame_upgrade_manager.get_relic_slot_count(generator_id, state.eternal_flame_state) <= 0:
		return false
	if get_relic(instance_id).is_empty():
		return false
	# A relic instance can only occupy one generator at a time.
	for equipped_generator_id in equipped.keys():
		if str(equipped[equipped_generator_id]) == instance_id:
			equipped.erase(equipped_generator_id)
			break
	equipped[generator_id] = instance_id
	return true

func unequip_relic(generator_id: String) -> void:
	equipped.erase(generator_id)

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
		for generator_id in equipped_data:
			var instance_id := str(equipped_data[generator_id])
			if not get_relic(instance_id).is_empty():
				equipped[str(generator_id)] = instance_id
	for relic in inventory:
		var instance_id := str(relic.get("instance_id", ""))
		if instance_id.begins_with("relic_"):
			_next_instance_number = maxi(_next_instance_number, int(instance_id.trim_prefix("relic_")) + 1)
