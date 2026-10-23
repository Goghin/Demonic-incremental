class_name RelicManager
extends RefCounted

const UNCOMMON_SECONDARY_STAT_POOL: Array[Dictionary] = [
	{"stat_type": "modifier", "modifier_type": ModifierTypes.PRODUCTION, "target_id": ResourceIds.HEAT, "roll_min": 1.03, "roll_max": 1.08, "description": "Heat production"},
	{"stat_type": "modifier", "modifier_type": ModifierTypes.PRODUCTION, "target_id": ResourceIds.MATTER, "roll_min": 1.03, "roll_max": 1.08, "description": "Matter production"},
	{"stat_type": "modifier", "modifier_type": ModifierTypes.INPUT_DRAW, "target_id": ResourceIds.HEAT, "roll_min": 0.92, "roll_max": 0.97, "description": "Heat draw reduction"},
	{"stat_type": "modifier", "modifier_type": ModifierTypes.INPUT_DRAW, "target_id": ResourceIds.MATTER, "roll_min": 0.92, "roll_max": 0.97, "description": "Matter draw reduction"},
	{"stat_type": "sensitivity", "sensitivity_targets": ["ashen_contamination", "ashen_contamination_cycle_speed"], "roll_min": 0.92, "roll_max": 0.97, "description": "Ash Contamination sensitivity reduction"},
	{"stat_type": "sensitivity", "sensitivity_targets": ["thermic_mass"], "roll_min": 1.03, "roll_max": 1.08, "description": "Thermic Mass sensitivity increase"}
]

const RELIC_DEFINITIONS: Dictionary = {
	# Tier 1 relics roll their strength once when the instance is created.
	"cinder_shard": {"display_name": "Cinder Shard", "family": "production", "modifier_type": ModifierTypes.PRODUCTION, "target_id": ResourceIds.HEAT, "roll_min": 1.05, "roll_max": 1.15, "description": "Increases Heat output by 5–15%.", "tier": 1},
	"ashbane_fragment": {"display_name": "Ashbane Fragment", "family": "production", "modifier_type": ModifierTypes.PRODUCTION, "target_id": ResourceIds.ASH, "roll_min": 0.85, "roll_max": 0.95, "description": "Reduces Ash production by 5–15%.", "tier": 1},
	"mite_core": {"display_name": "Mite Core", "family": "input_efficiency", "modifier_type": ModifierTypes.INPUT_DRAW, "target_id": ResourceIds.ASH, "roll_min": 1.05, "roll_max": 1.15, "description": "Increases Ash draw by 5–15%.", "tier": 1},
	"clockwork_ember": {"display_name": "Clockwork Ember", "family": "cycle_speed", "modifier_type": ModifierTypes.CYCLE_SPEED, "target_id": "", "roll_min": 1.05, "roll_max": 1.15, "description": "Increases cycle speed by 5–15%.", "tier": 1},
	"ruinheart": {"display_name": "Ruinheart", "family": "event_chance", "modifier_type": ModifierTypes.EVENT_CHANCE, "target_id": "critical_chance", "roll_min": 0.01, "roll_max": 0.05, "description": "Adds 1–5 percentage points to critical chance.", "tier": 1},
	"fracture_sigil": {"display_name": "Fracture Sigil", "family": "event_chance", "modifier_type": ModifierTypes.EVENT_CHANCE, "target_id": "downlevel_chance", "roll_min": 0.05, "roll_max": 0.15, "description": "Adds 5–15 percentage points to downleveling chance.", "tier": 1},
	# Retired definitions remain loadable for old saves, but are not rolled in new crafting.
	"void_lining": {"display_name": "Void Lining", "family": "input_efficiency", "multiplier": 0.90, "description": "Legacy relic: reduces resource input consumption by 10%.", "tier": 0},
	"emberheart_core": {"display_name": "Emberheart Core", "family": "production", "multiplier": 1.30, "description": "Legacy relic: increases a generator's output by 30%.", "tier": 0},
	"chronal_spring": {"display_name": "Chronal Spring", "family": "cycle_speed", "multiplier": 1.20, "description": "Legacy relic: increases cycle speed by 20%.", "tier": 0},
	"abyssal_lining": {"display_name": "Abyssal Lining", "family": "input_efficiency", "multiplier": 0.80, "description": "Legacy relic: reduces resource input consumption by 20%.", "tier": 0},
	"refined_emberheart_core": {"display_name": "Refined Emberheart Core", "family": "production", "modifier_type": ModifierTypes.PRODUCTION, "target_id": ResourceIds.HEAT, "roll_min": 1.15, "roll_max": 1.25, "description": "Increases Heat output by 15–25%.", "tier": 2, "secondary_rolls": UNCOMMON_SECONDARY_STAT_POOL},
	"perfected_chronal_spring": {"display_name": "Perfected Chronal Spring", "family": "cycle_speed", "modifier_type": ModifierTypes.CYCLE_SPEED, "target_id": "", "roll_min": 1.15, "roll_max": 1.25, "description": "Increases cycle speed by 15–25%.", "tier": 2, "secondary_rolls": UNCOMMON_SECONDARY_STAT_POOL},
	"abyssal_mite_core": {"display_name": "Abyssal Mite Core", "family": "input_efficiency", "modifier_type": ModifierTypes.INPUT_DRAW, "target_id": ResourceIds.ASH, "roll_min": 1.15, "roll_max": 1.25, "description": "Increases Ash draw by 15–25%.", "tier": 2, "secondary_rolls": UNCOMMON_SECONDARY_STAT_POOL},
	# Common stat-specialist relics.
	"ashveil_charm": {"display_name": "Ashveil Charm", "family": "sensitivity", "stat_type": "sensitivity", "sensitivity_targets": ["ashen_contamination", "ashen_contamination_cycle_speed"], "roll_min": 0.85, "roll_max": 0.95, "description": "Reduces Ash Contamination sensitivity by 5–15%.", "tier": 1},
	"thermic_resonator": {"display_name": "Thermic Resonator", "family": "sensitivity", "stat_type": "sensitivity", "sensitivity_targets": ["thermic_mass"], "roll_min": 1.05, "roll_max": 1.15, "description": "Increases Thermic Mass sensitivity by 5–15%.", "tier": 1},
	"matterheart": {"display_name": "Matterheart", "family": "production", "modifier_type": ModifierTypes.PRODUCTION, "target_id": ResourceIds.MATTER, "roll_min": 1.05, "roll_max": 1.15, "description": "Increases Matter production by 5–15%.", "tier": 1},
	"heat_siphon_valve": {"display_name": "Heat Siphon Valve", "family": "input_efficiency", "modifier_type": ModifierTypes.INPUT_DRAW, "target_id": ResourceIds.HEAT, "roll_min": 0.85, "roll_max": 0.95, "description": "Reduces Heat draw by 5–15%.", "tier": 1},
	"matter_siphon_valve": {"display_name": "Matter Siphon Valve", "family": "input_efficiency", "modifier_type": ModifierTypes.INPUT_DRAW, "target_id": ResourceIds.MATTER, "roll_min": 0.85, "roll_max": 0.95, "description": "Reduces Matter draw by 5–15%.", "tier": 1},
	# Uncommon variants roll a stronger primary stat and one additional stat.
	"azure_ashveil_charm": {"display_name": "Azure Ashveil Charm", "family": "sensitivity", "stat_type": "sensitivity", "sensitivity_targets": ["ashen_contamination", "ashen_contamination_cycle_speed"], "roll_min": 0.75, "roll_max": 0.90, "description": "Greatly reduces Ash Contamination sensitivity.", "tier": 2, "secondary_rolls": UNCOMMON_SECONDARY_STAT_POOL},
	"azure_thermic_resonator": {"display_name": "Azure Thermic Resonator", "family": "sensitivity", "stat_type": "sensitivity", "sensitivity_targets": ["thermic_mass"], "roll_min": 1.10, "roll_max": 1.25, "description": "Greatly increases Thermic Mass sensitivity.", "tier": 2, "secondary_rolls": UNCOMMON_SECONDARY_STAT_POOL},
	"refined_matterheart": {"display_name": "Refined Matterheart", "family": "production", "modifier_type": ModifierTypes.PRODUCTION, "target_id": ResourceIds.MATTER, "roll_min": 1.15, "roll_max": 1.25, "description": "Increases Matter production by 15–25%.", "tier": 2, "secondary_rolls": UNCOMMON_SECONDARY_STAT_POOL},
	"azure_heat_siphon_valve": {"display_name": "Azure Heat Siphon Valve", "family": "input_efficiency", "modifier_type": ModifierTypes.INPUT_DRAW, "target_id": ResourceIds.HEAT, "roll_min": 0.75, "roll_max": 0.90, "description": "Greatly reduces Heat draw.", "tier": 2, "secondary_rolls": UNCOMMON_SECONDARY_STAT_POOL},
	"azure_matter_siphon_valve": {"display_name": "Azure Matter Siphon Valve", "family": "input_efficiency", "modifier_type": ModifierTypes.INPUT_DRAW, "target_id": ResourceIds.MATTER, "roll_min": 0.75, "roll_max": 0.90, "description": "Greatly reduces Matter draw.", "tier": 2, "secondary_rolls": UNCOMMON_SECONDARY_STAT_POOL}
}

const STACKABLE_ITEM_DEFINITIONS: Dictionary = {
	"relic_shard": {
		"display_name": "Relic Shard",
		"description": "A fragment of reliquary essence, used in future relic crafting.",
		"glyph": "♦",
		"max_stack": 1000
	},
	"greater_relic_shard": {
		"display_name": "Greater Relic Shard",
		"description": "A condensed shard used to forge higher-tier relics.",
		"glyph": "✦",
		"max_stack": 1000
	}
}

const INVENTORY_SLOT_COUNT := 24

var inventory: Array[Dictionary] = []
var inventory_positions: Dictionary = {}
# Items in machine-owned crafting slots remain in inventory as owned instances,
# but do not occupy a Reliquary square while stored in a machine.
var machine_slots: Dictionary = {}
var equipped: Dictionary = {}
var _next_instance_number: int = 1
var _next_item_instance_number: int = 1

func ensure_starter_relic() -> void:
	for relic in inventory:
		if str(relic.get("definition_id", "")) == "cinder_shard":
			return
	add_relic("cinder_shard")

func add_relic(definition_id: String) -> String:
	if not RELIC_DEFINITIONS.has(definition_id):
		return ""
	var definition: Dictionary = RELIC_DEFINITIONS[definition_id]
	var instance_id := "relic_%d" % _next_instance_number
	_next_instance_number += 1
	var entry: Dictionary = {"instance_id": instance_id, "definition_id": definition_id}
	entry["rolled_value"] = _roll_relic_value(definition)
	var secondary_rolls: Variant = definition.get("secondary_rolls", [])
	if secondary_rolls is Array and not secondary_rolls.is_empty():
		var secondary: Dictionary = _roll_secondary_stat(definition)
		secondary["rolled_value"] = _roll_relic_value(secondary)
		entry["secondary_stat"] = secondary
	inventory.append(entry)
	inventory_positions[instance_id] = _find_first_available_inventory_slot()
	return instance_id


func _get_legacy_relic_value(definition_id: String) -> float:
	# Preserve fixed strengths from saves created before per-instance rolls.
	match definition_id:
		"cinder_shard":
			return 1.15
		"clockwork_ember":
			return 1.10
		"void_lining":
			return 0.90
		"emberheart_core":
			return 1.30
		"chronal_spring":
			return 1.20
		"abyssal_lining":
			return 0.80
	var definition: Dictionary = RELIC_DEFINITIONS.get(definition_id, {})
	return _roll_relic_value(definition)


func _roll_relic_value(definition: Dictionary) -> float:
	if definition.has("roll_min") and definition.has("roll_max"):
		return randf_range(
			float(definition["roll_min"]),
			float(definition["roll_max"])
		)
	return float(definition.get("multiplier", 1.0))


func _roll_secondary_stat(definition: Dictionary) -> Dictionary:
	var secondary_rolls: Variant = definition.get("secondary_rolls", [])
	if not secondary_rolls is Array:
		return {}
	var primary_type := str(definition.get("stat_type", "modifier"))
	var primary_modifier_type := str(definition.get("modifier_type", ""))
	var primary_target := str(definition.get("target_id", ""))
	var primary_sensitivity_targets: Array = definition.get("sensitivity_targets", [])
	var candidates: Array[Dictionary] = []
	for candidate_variant in secondary_rolls:
		if not candidate_variant is Dictionary:
			continue
		var candidate: Dictionary = candidate_variant
		if primary_type == "sensitivity":
			var candidate_targets: Array = candidate.get("sensitivity_targets", [])
			var overlaps := false
			for target in candidate_targets:
				if primary_sensitivity_targets.has(target):
					overlaps = true
					break
			if overlaps:
				continue
		elif (
			str(candidate.get("modifier_type", "")) == primary_modifier_type
			and str(candidate.get("target_id", "")) == primary_target
		):
			continue
		candidates.append(candidate.duplicate(true))
	if candidates.is_empty():
		return {}
	var result: Dictionary = candidates[randi_range(0, candidates.size() - 1)]
	result["rolled_value"] = _roll_relic_value(result)
	return result


func get_relic_modifier_value(relic: Dictionary) -> float:
	var definition := get_definition(str(relic.get("definition_id", "")))
	if definition.is_empty():
		return 1.0
	return float(relic.get("rolled_value", definition.get("multiplier", 1.0)))


func get_relic_description(relic: Dictionary) -> String:
	var definition := get_definition(str(relic.get("definition_id", "")))
	if definition.is_empty():
		return ""
	var description := str(definition.get("description", ""))
	var tier := int(definition.get("tier", 0))
	if tier == 1:
		description = "Common\\n" + description
	elif tier >= 2:
		description = "Uncommon\\n" + description
	var value := get_relic_modifier_value(relic)
	var modifier_type := str(definition.get("modifier_type", ""))
	if definition.has("roll_min"):
		if str(definition.get("stat_type", "")) == "sensitivity":
			var sensitivity_targets: Array = definition.get("sensitivity_targets", [])
			var sensitivity_name := "Ash Contamination" if not sensitivity_targets.is_empty() and str(sensitivity_targets[0]) == "ashen_contamination" else "Thermic Mass"
			var direction := "−" if value < 1.0 else "+"
			description += "\nRolled: %s%.1f%% sensitivity to %s" % [direction, absf(value - 1.0) * 100.0, sensitivity_name]
		elif bool(definition.get("dynamic", false)):
			description += "\nRolled coefficient: %.4f (effective strength changes with game state)" % value
		elif modifier_type == ModifierTypes.EVENT_CHANCE:
			var stat_name := "Critical chance" if str(definition.get("target_id", "")) == "critical_chance" else "Downleveling chance"
			description += "\nRolled: +%.1f percentage points to %s" % [value * 100.0, stat_name]
		else:
			var percent := absf(value - 1.0) * 100.0
			var direction := "−" if value < 1.0 else "+"
			description += "\nRolled: %s%.1f%%" % [direction, percent]
	var secondary: Variant = relic.get("secondary_stat", {})
	if secondary is Dictionary and not secondary.is_empty():
		var secondary_value := float(secondary.get("rolled_value", 1.0))
		var secondary_type := str(secondary.get("stat_type", "modifier"))
		var secondary_description := str(secondary.get("description", "Additional stat"))
		var secondary_direction := "−" if secondary_value < 1.0 else "+"
		if secondary_type == "sensitivity":
			description += "\nBonus: %s %s%.1f%%" % [secondary_description, secondary_direction, absf(secondary_value - 1.0) * 100.0]
		else:
			description += "\nBonus: %s %s%.1f%%" % [secondary_description, secondary_direction, absf(secondary_value - 1.0) * 100.0]
	return description

func _find_first_available_inventory_slot() -> int:
	var occupied: Dictionary = {}
	for position_variant in inventory_positions.values():
		occupied[int(position_variant)] = true
	var slot_index := 0
	while occupied.has(slot_index):
		slot_index += 1
	return slot_index


func get_stackable_item_definition(item_id: String) -> Dictionary:
	return STACKABLE_ITEM_DEFINITIONS.get(item_id, {})


func get_inventory_entry_by_instance_id(instance_id: String) -> Dictionary:
	for entry in inventory:
		if str(entry.get("instance_id", "")) == instance_id:
			return entry
	return {}


func get_inventory_entry_type(entry: Dictionary) -> String:
	var definition_id := str(entry.get("definition_id", ""))
	if RELIC_DEFINITIONS.has(definition_id):
		return "relic"
	if STACKABLE_ITEM_DEFINITIONS.has(str(entry.get("item_id", ""))):
		return "stackable"
	return ""


func get_inventory_entry_at_slot(slot_index: int) -> Dictionary:
	if slot_index < 0:
		return {}
	for entry in inventory:
		var instance_id := str(entry.get("instance_id", ""))
		if int(inventory_positions.get(instance_id, -1)) != slot_index:
			continue
		if get_inventory_entry_type(entry) == "relic" and _is_relic_equipped(instance_id):
			continue
		return entry.duplicate(true)
	return {}


func get_inventory_relic_id_at_slot(slot_index: int) -> String:
	var entry := get_inventory_entry_at_slot(slot_index)
	if get_inventory_entry_type(entry) != "relic":
		return ""
	return str(entry.get("instance_id", ""))


func add_stackable_item(item_id: String, quantity: int) -> int:
	var definition := get_stackable_item_definition(item_id)
	if definition.is_empty() or quantity <= 0:
		return 0

	var remaining := quantity
	var max_stack := maxi(1, int(definition.get("max_stack", 1000)))
	for entry in inventory:
		if str(entry.get("item_id", "")) != item_id:
			continue
		var current_quantity := int(entry.get("quantity", 0))
		var added := mini(remaining, max_stack - current_quantity)
		if added <= 0:
			continue
		entry["quantity"] = current_quantity + added
		remaining -= added
		if remaining <= 0:
			break

	while remaining > 0:
		var stack_quantity := mini(remaining, max_stack)
		var instance_id := "item_%d" % _next_item_instance_number
		_next_item_instance_number += 1
		inventory.append({
			"instance_id": instance_id,
			"item_id": item_id,
			"quantity": stack_quantity
		})
		inventory_positions[instance_id] = _find_first_available_inventory_slot()
		remaining -= stack_quantity

	return quantity


func get_inventory_slot_count() -> int:
	var highest_slot := INVENTORY_SLOT_COUNT - 1
	for position_variant in inventory_positions.values():
		highest_slot = maxi(highest_slot, int(position_variant))
	return highest_slot + 1


func _is_relic_equipped(instance_id: String) -> bool:
	for generator_id_variant in equipped.keys():
		if get_equipped_relic_ids(str(generator_id_variant)).has(instance_id):
			return true
	return false


func move_relic_to_inventory(instance_id: String, target_slot_index: int) -> bool:
	if get_relic(instance_id).is_empty():
		return false
	return move_inventory_entry_to_slot(instance_id, target_slot_index)


func move_inventory_entry_to_slot(instance_id: String, target_slot_index: int) -> bool:
	if target_slot_index < 0:
		return false
	var source_entry := get_inventory_entry_by_instance_id(instance_id)
	if source_entry.is_empty():
		return false

	var previous_slot := int(inventory_positions.get(instance_id, -1))
	var target_entry := get_inventory_entry_at_slot(target_slot_index)
	var target_instance_id := str(target_entry.get("instance_id", ""))
	if target_instance_id == instance_id:
		return true

	# Compatible stacks merge up to their configured capacity. Any remainder
	# stays in its original stack and therefore keeps its inventory position.
	if (
		get_inventory_entry_type(source_entry) == "stackable"
		and get_inventory_entry_type(target_entry) == "stackable"
		and str(source_entry.get("item_id", "")) == str(target_entry.get("item_id", ""))
	):
		var definition := get_stackable_item_definition(str(source_entry.get("item_id", "")))
		var max_stack := maxi(1, int(definition.get("max_stack", 1000)))
		var target_quantity := int(target_entry.get("quantity", 0))
		var source_quantity := int(source_entry.get("quantity", 0))
		var transferred := mini(source_quantity, maxi(0, max_stack - target_quantity))
		if transferred <= 0:
			# Full stacks can still be rearranged like any other inventory items.
			pass
		else:
			for entry in inventory:
				if str(entry.get("instance_id", "")) == target_instance_id:
					entry["quantity"] = target_quantity + transferred
				if str(entry.get("instance_id", "")) == instance_id:
					entry["quantity"] = source_quantity - transferred
			if source_quantity == transferred:
				_remove_inventory_entry(instance_id)
			return true

	if target_instance_id != "":
		if previous_slot < 0:
			return false
		inventory_positions[target_instance_id] = previous_slot
	inventory_positions[instance_id] = target_slot_index
	return true


func _remove_inventory_entry(instance_id: String) -> void:
	for index in range(inventory.size() - 1, -1, -1):
		if str(inventory[index].get("instance_id", "")) == instance_id:
			inventory.remove_at(index)
			break
	inventory_positions.erase(instance_id)



func get_machine_entry_at_slot(generator_id: String, slot_index: int) -> Dictionary:
	if slot_index < 0:
		return {}
	var slots: Variant = machine_slots.get(generator_id, {})
	if not slots is Dictionary:
		return {}
	var instance_id := str(slots.get(str(slot_index), ""))
	if instance_id == "":
		return {}
	return get_inventory_entry_by_instance_id(instance_id).duplicate(true)


func move_inventory_entry_to_machine_slot(
	instance_id: String,
	generator_id: String,
	slot_index: int
) -> bool:
	if generator_id == "" or slot_index < 0:
		return false
	var entry := get_inventory_entry_by_instance_id(instance_id)
	if entry.is_empty() or not inventory_positions.has(instance_id):
		return false
	if get_inventory_entry_type(entry) == "relic" and _is_relic_equipped(instance_id):
		return false

	var slots: Dictionary = machine_slots.get(generator_id, {}).duplicate()
	var previous_instance_id := str(slots.get(str(slot_index), ""))
	if previous_instance_id == instance_id:
		return true
	# Returning a displaced item to the Reliquary cannot fail: inventory squares
	# expand to accommodate owned items, so mode changes never destroy contents.
	if previous_instance_id != "":
		inventory_positions[previous_instance_id] = _find_first_available_inventory_slot()
	slots[str(slot_index)] = instance_id
	machine_slots[generator_id] = slots
	inventory_positions.erase(instance_id)
	return true


func move_machine_entry_to_inventory(generator_id: String, slot_index: int) -> bool:
	if slot_index < 0:
		return false
	var slots: Variant = machine_slots.get(generator_id, {})
	if not slots is Dictionary:
		return false
	var instance_id := str(slots.get(str(slot_index), ""))
	if instance_id == "":
		return true
	if get_inventory_entry_by_instance_id(instance_id).is_empty():
		slots.erase(str(slot_index))
		if slots.is_empty():
			machine_slots.erase(generator_id)
		return false
	slots.erase(str(slot_index))
	if slots.is_empty():
		machine_slots.erase(generator_id)
	else:
		machine_slots[generator_id] = slots
	inventory_positions[instance_id] = _find_first_available_inventory_slot()
	return true


func resize_machine_slots(generator_id: String, visible_slot_count: int) -> bool:
	if generator_id == "" or visible_slot_count < 0:
		return false
	var slots: Variant = machine_slots.get(generator_id, {})
	if not slots is Dictionary:
		return true
	var indices: Array[int] = []
	for slot_key in slots.keys():
		if not str(slot_key).is_valid_int():
			continue
		var slot_index := int(slot_key)
		if slot_index >= visible_slot_count:
			indices.append(slot_index)
	indices.sort()
	for slot_index in indices:
		if not move_machine_entry_to_inventory(generator_id, slot_index):
			return false
	return true


func consume_machine_entry(
	generator_id: String,
	slot_index: int,
	quantity: int = 0
) -> bool:
	var entry := get_machine_entry_at_slot(generator_id, slot_index)
	if entry.is_empty():
		return false
	var instance_id := str(entry.get("instance_id", ""))
	if get_inventory_entry_type(entry) == "stackable":
		var current_quantity := int(entry.get("quantity", 0))
		var amount_to_consume := current_quantity if quantity <= 0 else quantity
		if amount_to_consume <= 0 or amount_to_consume > current_quantity:
			return false
		for inventory_entry in inventory:
			if str(inventory_entry.get("instance_id", "")) != instance_id:
				continue
			var remaining := current_quantity - amount_to_consume
			if remaining <= 0:
				_remove_inventory_entry(instance_id)
				var slots: Dictionary = machine_slots.get(generator_id, {}).duplicate()
				slots.erase(str(slot_index))
				if slots.is_empty():
					machine_slots.erase(generator_id)
				else:
					machine_slots[generator_id] = slots
			else:
				inventory_entry["quantity"] = remaining
			return true
		return false
	_remove_inventory_entry(instance_id)
	var relic_slots: Dictionary = machine_slots.get(generator_id, {}).duplicate()
	relic_slots.erase(str(slot_index))
	if relic_slots.is_empty():
		machine_slots.erase(generator_id)
	else:
		machine_slots[generator_id] = relic_slots
	return true



func can_satisfy_crafting_recipe(generator_id: String, requirements: Array[Dictionary]) -> bool:
	for slot_index in range(requirements.size()):
		var requirement: Dictionary = requirements[slot_index]
		var entry := get_machine_entry_at_slot(generator_id, slot_index)
		if entry.is_empty():
			return false
		var entry_type := get_inventory_entry_type(entry)
		var required_type := str(requirement.get("item_type", ""))
		if required_type != "" and entry_type != required_type:
			return false
		var required_item_id := str(requirement.get("item_id", ""))
		if required_item_id != "":
			var actual_item_id := str(entry.get("item_id", entry.get("definition_id", "")))
			if actual_item_id != required_item_id:
				return false
		var required_quantity := maxi(1, int(requirement.get("quantity", 1)))
		if entry_type == "stackable" and int(entry.get("quantity", 0)) < required_quantity:
			return false
		if entry_type == "relic" and required_quantity != 1:
			return false
	return true


func consume_crafting_recipe(generator_id: String, requirements: Array[Dictionary]) -> bool:
	if not can_satisfy_crafting_recipe(generator_id, requirements):
		return false
	for slot_index in range(requirements.size()):
		var requirement: Dictionary = requirements[slot_index]
		var quantity := maxi(1, int(requirement.get("quantity", 1)))
		if not consume_machine_entry(generator_id, slot_index, quantity):
			return false
	return true

func get_relic(instance_id: String) -> Dictionary:
	for entry in inventory:
		if (
			str(entry.get("instance_id", "")) == instance_id
			and RELIC_DEFINITIONS.has(str(entry.get("definition_id", "")))
		):
			return entry
	return {}

func get_definition(definition_id: String) -> Dictionary:
	return RELIC_DEFINITIONS.get(definition_id, {})


func add_random_relic_for_tier(tier: int) -> String:
	if tier <= 0:
		return ""
	var candidates: Array[String] = []
	for definition_id_variant in RELIC_DEFINITIONS.keys():
		var definition_id := str(definition_id_variant)
		var definition: Dictionary = RELIC_DEFINITIONS[definition_id]
		if int(definition.get("tier", 1)) == tier:
			candidates.append(definition_id)
	if candidates.is_empty():
		return ""
	candidates.sort()
	return add_relic(candidates[randi_range(0, candidates.size() - 1)])

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
			"family": str(definition.get("family", "")),
			"rolled_value": get_relic_modifier_value(relic),
			"description": get_relic_description(relic),
			"slot_index": int(inventory_positions.get(str(relic.get("instance_id", "")), 0))
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
	var generator_slots: Variant = equipped.get(generator_id, {})
	if generator_slots is Dictionary:
		for slot_key in generator_slots.keys():
			var instance_id := str(generator_slots[slot_key])
			if instance_id != "":
				result.append(instance_id)
	elif generator_slots is String and str(generator_slots) != "":
		result.append(str(generator_slots))
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

	# Equipped relics no longer occupy a visible inventory square.
	inventory_positions.erase(instance_id)

	# A relic instance can occupy only one slot across all generators.
	for equipped_generator_variant in equipped.keys():
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

	var existing_slots: Variant = equipped.get(generator_id, {})
	var slots: Dictionary = {}
	if existing_slots is Dictionary:
		slots = existing_slots.duplicate()
	elif existing_slots is String and str(existing_slots) != "":
		slots["0"] = str(existing_slots)
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

	var modifier_type := str(definition.get("modifier_type", ""))
	var target_id := str(definition.get("target_id", ""))
	if str(definition.get("stat_type", "")) == "sensitivity":
		var sensitivity_targets: Variant = definition.get("sensitivity_targets", [])
		if sensitivity_targets is Array:
			for sensitivity in generator.modifier_sensitivities:
				if sensitivity.source_upgrade_id.begins_with("relic:") and sensitivity_targets.has(sensitivity.modifier_id):
					return "Active"
		return "Inactive: no matching sensitivity target"
	if modifier_type == "":
		match str(definition.get("family", "")):
			"production":
				modifier_type = ModifierTypes.PRODUCTION
			"cycle_speed":
				modifier_type = ModifierTypes.CYCLE_SPEED
			"input_efficiency":
				modifier_type = ModifierTypes.INPUT_DRAW

	match modifier_type:
		ModifierTypes.PRODUCTION:
			if generator.get_operation_mode() != null and generator.get_operation_mode().is_resource_transfer:
				return "Inactive in resource-transfer mode"
			for output in generator.get_active_outputs():
				if output.unlocked and (target_id == "" or output.resource_id == target_id):
					return "Active"
			return "Inactive: no matching output"
		ModifierTypes.INPUT_DRAW:
			for input in generator.get_active_inputs():
				if target_id == "" or input.resource_id == target_id:
					return "Active"
			return "Inactive: no matching input"
		ModifierTypes.CYCLE_SPEED:
			return "Active" if generator.definition.cycle_based else "Inactive: no cycle"
		ModifierTypes.EVENT_CHANCE:
			if not generator.definition.cycle_based:
				return "Inactive: no cycle"
			for effect in generator.event_effects:
				if target_id == "critical_chance" and effect.event_id == "forge_critical":
					return "Active"
				if target_id == "downlevel_chance" and effect.event_action == UpgradeEffectTypes.EVENT_ACTION_DECREASE_GENERATOR_LEVEL:
					return "Active"
			return "Inactive: no matching event"
	return "Inactive"

func get_save_data() -> Dictionary:
	return {
		"inventory": inventory.duplicate(true),
		"inventory_positions": inventory_positions.duplicate(true),
		"machine_slots": machine_slots.duplicate(true),
		"equipped": equipped.duplicate(true),
		"next_instance_number": _next_instance_number,
		"next_item_instance_number": _next_item_instance_number
	}

func load_save_data(data: Dictionary) -> void:
	inventory.clear()
	inventory_positions.clear()
	machine_slots.clear()
	equipped.clear()
	_next_instance_number = maxi(1, int(data.get("next_instance_number", 1)))
	_next_item_instance_number = maxi(1, int(data.get("next_item_instance_number", 1)))
	var inventory_data: Variant = data.get("inventory", [])
	if inventory_data is Array:
		for entry in inventory_data:
			if not entry is Dictionary:
				continue
			var instance_id := str(entry.get("instance_id", ""))
			if instance_id == "":
				continue
			var definition_id := str(entry.get("definition_id", ""))
			var item_id := str(entry.get("item_id", ""))
			if RELIC_DEFINITIONS.has(definition_id):
				var relic_entry: Dictionary = {
					"instance_id": instance_id,
					"definition_id": definition_id
				}
				relic_entry["rolled_value"] = float(
					entry.get("rolled_value", _get_legacy_relic_value(definition_id))
				)
				var saved_secondary: Variant = entry.get("secondary_stat", {})
				if saved_secondary is Dictionary and not saved_secondary.is_empty():
					relic_entry["secondary_stat"] = saved_secondary.duplicate(true)
				elif RELIC_DEFINITIONS[definition_id].has("secondary_rolls"):
					var secondary: Dictionary = _roll_secondary_stat(RELIC_DEFINITIONS[definition_id])
					if not secondary.is_empty():
						relic_entry["secondary_stat"] = secondary
				inventory.append(relic_entry)
			elif STACKABLE_ITEM_DEFINITIONS.has(item_id):
				var quantity := int(entry.get("quantity", 0))
				if quantity <= 0:
					continue
				var max_stack := maxi(1, int(STACKABLE_ITEM_DEFINITIONS[item_id].get("max_stack", 1000)))
				inventory.append({
					"instance_id": instance_id,
					"item_id": item_id,
					"quantity": mini(quantity, max_stack)
				})
	# Restore saved inventory squares. Older saves fall back to the relic's saved array order.
	var saved_positions: Variant = data.get("inventory_positions", {})
	var claimed_inventory_slots: Dictionary = {}
	if saved_positions is Dictionary:
		for instance_id_variant in saved_positions.keys():
			var instance_id := str(instance_id_variant)
			var slot_index := int(saved_positions[instance_id_variant])
			if get_inventory_entry_by_instance_id(instance_id).is_empty() or slot_index < 0 or claimed_inventory_slots.has(slot_index):
				continue
			inventory_positions[instance_id] = slot_index
			claimed_inventory_slots[slot_index] = true
	for relic_index in range(inventory.size()):
		var instance_id := str(inventory[relic_index].get("instance_id", ""))
		if not inventory_positions.has(instance_id):
			var slot_index := _find_first_available_inventory_slot()
			inventory_positions[instance_id] = slot_index
			claimed_inventory_slots[slot_index] = true

	# Restore machine crafting slots after inventory instances have been validated.
	var saved_machine_slots: Variant = data.get("machine_slots", {})
	if saved_machine_slots is Dictionary:
		var claimed_machine_instances: Dictionary = {}
		for generator_variant in saved_machine_slots.keys():
			var generator_id := str(generator_variant)
			var saved_slots: Variant = saved_machine_slots[generator_variant]
			if not saved_slots is Dictionary:
				continue
			var normalized_slots: Dictionary = {}
			for slot_key in saved_slots.keys():
				var slot_index_text := str(slot_key)
				var instance_id := str(saved_slots[slot_key])
				if (
					not slot_index_text.is_valid_int()
					or int(slot_index_text) < 0
					or get_inventory_entry_by_instance_id(instance_id).is_empty()
					or claimed_machine_instances.has(instance_id)
				):
					continue
				normalized_slots[slot_index_text] = instance_id
				claimed_machine_instances[instance_id] = true
				inventory_positions.erase(instance_id)
			if not normalized_slots.is_empty():
				machine_slots[generator_id] = normalized_slots

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
				if not str(slot_key).is_valid_int() or int(slot_key) < 0:
					normalized_slots.erase(slot_key)
					continue
				if get_relic(instance_id).is_empty() or claimed_instances.has(instance_id):
					normalized_slots.erase(slot_key)
					continue
				claimed_instances[instance_id] = true
			if not normalized_slots.is_empty():
				equipped[generator_id] = normalized_slots
	for generator_id_variant in equipped.keys():
		for instance_id in get_equipped_relic_ids(str(generator_id_variant)):
			inventory_positions.erase(instance_id)
	for generator_variant in machine_slots.keys():
		var slots: Dictionary = machine_slots[generator_variant]
		for instance_variant in slots.values():
			inventory_positions.erase(str(instance_variant))

	for entry in inventory:
		var instance_id := str(entry.get("instance_id", ""))
		if instance_id.begins_with("relic_"):
			_next_instance_number = maxi(_next_instance_number, int(instance_id.trim_prefix("relic_")) + 1)
		elif instance_id.begins_with("item_"):
			_next_item_instance_number = maxi(
				_next_item_instance_number,
				int(instance_id.trim_prefix("item_")) + 1
			)
