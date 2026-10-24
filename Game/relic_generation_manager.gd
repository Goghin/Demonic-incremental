class_name RelicGenerationManager
extends RefCounted


# Tier configuration owns the progression rules. Critical promotion follows the
# next configured tier instead of assuming tiers are consecutive integers.
const TIER_DEFINITIONS: Dictionary = {
	1: {
		"display_name": "Common",
		"display_color": "#61d97a",
		"weight": 100.0,
		"secondary_effect_count": 0
	},
	2: {
		"display_name": "Uncommon",
		"display_color": "#61b3ff",
		"weight": 35.0,
		"secondary_effect_count": 1
	}
}

# Effect definitions are data, not generation branches. Add an entry here to
# make a new effect available to every tier whose roll range it defines.
# A blank modifier target means "all matching inputs/outputs".
const EFFECT_DEFINITIONS: Dictionary = {
	"output_increase": {
		"stat_group": "output",
		"modifier_type": ModifierTypes.PRODUCTION,
		"target_id": "",
		# Each option is equally likely by default. Keep these options in data so
		# resource targeting can be tuned without changing the roll algorithm.
		"target_options": [
			{"target_id": "", "description_label": "All output production"},
			{"target_id": ResourceIds.HEAT},
			{"target_id": ResourceIds.MATTER},
			{"target_id": ResourceIds.ASH}
		],
		"weight": 60.0,
		"secondary_weight": 20.0,
		"roll_ranges": {1: [1.05, 1.12], 2: [1.15, 1.25]},
		"affix_position": "prefix",
		"affix_text": "Potent",
		"description_label": "All output production",
		"description_mode": "multiplier"
	},
	"output_decrease": {
		"stat_group": "output",
		"modifier_type": ModifierTypes.PRODUCTION,
		"target_id": "",
		"target_options": [
			{"target_id": "", "description_label": "All output production"},
			{"target_id": ResourceIds.HEAT},
			{"target_id": ResourceIds.MATTER},
			{"target_id": ResourceIds.ASH}
		],
		"weight": 35.0,
		"secondary_weight": 12.0,
		"roll_ranges": {1: [0.88, 0.97], 2: [0.75, 0.90]},
		"affix_position": "prefix",
		"affix_text": "Muted",
		"description_label": "All output production",
		"description_mode": "multiplier"
	},
	"input_draw_reduction": {
		"stat_group": "input_draw",
		"modifier_type": ModifierTypes.INPUT_DRAW,
		"target_id": "",
		"target_options": [
			{"target_id": "", "description_label": "All input draw"},
			{"target_id": ResourceIds.HEAT},
			{"target_id": ResourceIds.MATTER},
			{"target_id": ResourceIds.ASH}
		],
		"weight": 55.0,
		"secondary_weight": 20.0,
		"roll_ranges": {1: [0.90, 0.97], 2: [0.75, 0.90]},
		"affix_position": "prefix",
		"affix_text": "Efficient",
		"description_label": "All input draw",
		"description_mode": "multiplier"
	},
	"input_draw_increase": {
		"stat_group": "input_draw",
		"modifier_type": ModifierTypes.INPUT_DRAW,
		"target_id": "",
		"target_options": [
			{"target_id": "", "description_label": "All input draw"},
			{"target_id": ResourceIds.HEAT},
			{"target_id": ResourceIds.MATTER},
			{"target_id": ResourceIds.ASH}
		],
		"weight": 30.0,
		"secondary_weight": 10.0,
		"roll_ranges": {1: [1.05, 1.12], 2: [1.15, 1.25]},
		"affix_position": "prefix",
		"affix_text": "Voracious",
		"description_label": "All input draw",
		"description_mode": "multiplier"
	},
	"sensitivity_reduction": {
		"stat_group": "sensitivity",
		"stat_type": "sensitivity",
		"sensitivity_targets": ["*"],
		"weight": 45.0,
		"secondary_weight": 16.0,
		"roll_ranges": {1: [0.90, 0.97], 2: [0.75, 0.90]},
		"affix_position": "prefix",
		"affix_text": "Resistant",
		"description_label": "All supported sensitivities",
		"description_mode": "multiplier"
	},
	"sensitivity_increase": {
		"stat_group": "sensitivity",
		"stat_type": "sensitivity",
		"sensitivity_targets": ["*"],
		"weight": 25.0,
		"secondary_weight": 8.0,
		"roll_ranges": {1: [1.05, 1.12], 2: [1.10, 1.25]},
		"affix_position": "prefix",
		"affix_text": "Volatile",
		"description_label": "All supported sensitivities",
		"description_mode": "multiplier"
	},
	"cycle_speed_increase": {
		"stat_group": "cycle_speed",
		"modifier_type": ModifierTypes.CYCLE_SPEED,
		"target_id": "",
		"weight": 25.0,
		"secondary_weight": 10.0,
		"roll_ranges": {1: [1.05, 1.12], 2: [1.15, 1.25]},
		"affix_position": "suffix",
		"affix_text": "of Acceleration",
		"description_label": "Cycle speed",
		"description_mode": "multiplier"
	},
	"critical_chance": {
		"stat_group": "event_chance",
		"modifier_type": ModifierTypes.EVENT_CHANCE,
		"target_id": "critical_chance",
		"weight": 8.0,
		"secondary_weight": 4.0,
		"roll_ranges": {1: [0.01, 0.03], 2: [0.03, 0.06]},
		"affix_position": "suffix",
		"affix_text": "of Fortune",
		"description_label": "Critical chance",
		"description_mode": "percentage_points"
	}
}

const BASE_NAMES: Array[String] = [
	"Cinder Shard",
	"Ashglass Core",
	"Obsidian Heart",
	"Emberstone",
	"Void Fragment",
	"Molten Sigil",
	"Umbral Crystal",
	"Scoria Relic"
]


func get_available_tiers() -> Array[int]:
	var tiers: Array[int] = []
	for tier_variant in TIER_DEFINITIONS.keys():
		tiers.append(int(tier_variant))
	tiers.sort()
	return tiers


func get_tier_definition(tier: int) -> Dictionary:
	return TIER_DEFINITIONS.get(tier, {}).duplicate(true)


func get_highest_tier() -> int:
	var tiers := get_available_tiers()
	return tiers.back() if not tiers.is_empty() else 0


func get_next_tier(tier: int) -> int:
	for candidate_tier in get_available_tiers():
		if candidate_tier > tier:
			return candidate_tier
	return tier


func generate_relic(requested_tier: int, critical_chance: float = 0.0) -> Dictionary:
	var available_tiers := get_available_tiers()
	if available_tiers.is_empty():
		return {}
	if not TIER_DEFINITIONS.has(requested_tier):
		return {}

	var final_tier := requested_tier
	var is_critical := critical_chance >= 1.0 or (
		critical_chance > 0.0 and randf() < critical_chance
	)
	if is_critical:
		final_tier = get_next_tier(requested_tier)

	var primary_effect := _roll_effect_for_tier(final_tier, "")
	if primary_effect.is_empty():
		return {}

	var generated_definition := primary_effect.duplicate(true)
	generated_definition["tier"] = final_tier
	var tier_data: Dictionary = TIER_DEFINITIONS.get(final_tier, {})
	generated_definition["rarity_name"] = str(tier_data.get("display_name", "Tier %d" % final_tier))
	generated_definition["rarity_color"] = str(tier_data.get("display_color", "#ffffff"))
	generated_definition["display_name"] = _make_display_name(primary_effect)
	generated_definition["family"] = _get_family_for_stat_group(str(primary_effect.get("stat_group", "")))
	generated_definition["generated"] = true
	generated_definition["effect_id"] = str(primary_effect.get("effect_id", ""))

	var result: Dictionary = {
		"tier": final_tier,
		"requested_tier": requested_tier,
		"critical_craft": is_critical and final_tier > requested_tier,
		"generated_definition": generated_definition,
		"rolled_value": float(primary_effect.get("rolled_value", 1.0))
	}

	var secondary_count := maxi(0, int(tier_data.get("secondary_effect_count", 0)))
	var secondary_stats: Array[Dictionary] = []
	var excluded_group := str(primary_effect.get("stat_group", ""))
	for _index in range(secondary_count):
		var secondary := _roll_effect_for_tier(final_tier, excluded_group, "secondary_weight")
		if secondary.is_empty():
			continue
		secondary_stats.append(secondary)
		excluded_group = str(secondary.get("stat_group", excluded_group))
	if not secondary_stats.is_empty():
		# Preserve the current save shape for the first bonus stat.
		result["secondary_stat"] = secondary_stats[0]
	if secondary_stats.size() > 1:
		result["additional_secondary_stats"] = secondary_stats.slice(1)

	return result


func _roll_effect_for_tier(tier: int, excluded_group: String, weight_key: String = "weight") -> Dictionary:
	var candidates: Array[Dictionary] = []
	for effect_id_variant in EFFECT_DEFINITIONS.keys():
		var effect_id := str(effect_id_variant)
		var effect: Dictionary = EFFECT_DEFINITIONS[effect_id]
		if not effect.get("roll_ranges", {}).has(tier):
			continue
		if excluded_group != "" and str(effect.get("stat_group", "")) == excluded_group:
			continue
		if float(effect.get(weight_key, 0.0)) <= 0.0:
			continue
		var candidate := effect.duplicate(true)
		candidate["effect_id"] = effect_id
		candidates.append(candidate)
	if candidates.is_empty():
		return {}

	var selected := _weighted_pick(candidates, weight_key)
	if selected.is_empty():
		return {}
	var roll_ranges: Dictionary = selected.get("roll_ranges", {})
	var range_values: Array = roll_ranges.get(tier, [])
	if range_values.size() < 2:
		return {}
	selected["rolled_value"] = randf_range(float(range_values[0]), float(range_values[1]))
	_apply_target_option(selected)
	selected.erase("roll_ranges")
	selected.erase("target_options")
	selected.erase("weight")
	selected.erase("secondary_weight")
	return selected


func _apply_target_option(effect: Dictionary) -> void:
	var options: Variant = effect.get("target_options", [])
	if not options is Array or options.is_empty():
		return
	var candidates: Array[Dictionary] = []
	for option_variant in options:
		if option_variant is Dictionary:
			candidates.append(option_variant)
	if candidates.is_empty():
		return
	var selected_option := candidates[randi_range(0, candidates.size() - 1)]
	effect["target_id"] = str(selected_option.get("target_id", ""))
	# A blank target is universal. Resource-specific descriptions are generated
	# from the chosen target by RelicManager, avoiding stale "all resources" text.
	if selected_option.has("description_label"):
		effect["description_label"] = str(selected_option["description_label"])
	else:
		effect["description_label"] = ""


func _weighted_pick(candidates: Array[Dictionary], weight_key: String) -> Dictionary:
	var total_weight := 0.0
	for candidate in candidates:
		total_weight += maxf(0.0, float(candidate.get(weight_key, 0.0)))
	if total_weight <= 0.0:
		return {}

	var roll := randf() * total_weight
	for candidate in candidates:
		roll -= maxf(0.0, float(candidate.get(weight_key, 0.0)))
		if roll < 0.0:
			return candidate.duplicate(true)
	return candidates.back().duplicate(true)


func _get_family_for_stat_group(stat_group: String) -> String:
	match stat_group:
		"output":
			return "production"
		"input_draw":
			return "input_efficiency"
		_:
			return stat_group


func _make_display_name(effect: Dictionary) -> String:
	var base_name := BASE_NAMES[randi_range(0, BASE_NAMES.size() - 1)]
	var affix := str(effect.get("affix_text", ""))
	match str(effect.get("affix_position", "prefix")):
		"suffix":
			return "%s %s" % [base_name, affix] if affix != "" else base_name
		"prefix":
			return "%s %s" % [affix, base_name] if affix != "" else base_name
		_:
			return base_name
