class_name GameStats
extends RefCounted


var state: GameState


func _init(game_state: GameState) -> void:
	state = game_state


# ------------------------------------------------------------
# RESOURCE RATES
# ------------------------------------------------------------

# Potential production rate.
#
# This represents what all unlocked generators WOULD produce
# if they were currently operating.
func get_resource_production_per_second(
	resource_id: String
	) -> float:
	
	var total = 0.0
	
	for generator in state.get_generators().values():
		if not generator.unlocked:
			continue
		
		var outputs = generator.get_production_per_second(
			state
		)
		
		for output in outputs:
			if output.resource_id == resource_id:
				total += output.amount_per_second
	
	return total


# Actual production rate.
#
# Only generators which are currently operating contribute.
func get_resource_actual_production_per_second(
	resource_id: String
	) -> float:
	
	var total = 0.0
	
	for generator in state.get_generators().values():
		if not generator.unlocked:
			continue
		
		if not generator.is_operating():
			continue
		
		var outputs = generator.get_production_per_second(
			state
		)
		
		for output in outputs:
			if output.resource_id == resource_id:
				total += output.amount_per_second
	
	return total


# Potential consumption rate.
#
# This represents the maximum input consumption if all
# unlocked generators were operating.
func get_resource_consumption_per_second(
	resource_id: String
	) -> float:
	
	var total = 0.0
	
	for generator in state.get_generators().values():
		if not generator.unlocked:
			continue
		
		for input in generator.definition.inputs:
			if input.resource_id != resource_id:
				continue
			
			var input_rate = generator.get_input_rate(
				input,
				state
			)
			
			total += (
				input_rate
				* generator.level
			)
	
	return total


# Actual consumption rate.
#
# Only generators which are currently operating contribute.
func get_resource_actual_consumption_per_second(
	resource_id: String
	) -> float:
	
	var total = 0.0
	
	for generator in state.get_generators().values():
		if not generator.unlocked:
			continue
		
		if not generator.is_operating():
			continue
		
		for input in generator.definition.inputs:
			if input.resource_id != resource_id:
				continue
			
			var input_rate = generator.get_input_rate(
				input,
				state
			)
			
			total += (
				input_rate
				* generator.level
			)
	
	if resource_id == ResourceIds.HEAT:
		total += get_heat_leak_per_second()
	
	return total


# Potential net rate.
func get_resource_net_per_second(
	resource_id: String
	) -> float:
	
	return (
		get_resource_production_per_second(resource_id)
		- get_resource_consumption_per_second(resource_id)
	)


# Actual net rate.
func get_resource_actual_net_per_second(
	resource_id: String
	) -> float:
	
	return (
		get_resource_actual_production_per_second(
			resource_id
		)
		- get_resource_actual_consumption_per_second(
			resource_id
		)
	)


# ------------------------------------------------------------
# GENERATOR RATES
# ------------------------------------------------------------

# Potential production rate for one generator.
func get_generator_production_per_second(
	generator_id: String,
	resource_id: String
	) -> float:
	
	var generator = state.get_generator(
		generator_id
	)
	
	if generator == null:
		return 0.0
	
	if not generator.unlocked:
		return 0.0
	
	var total = 0.0
	
	var outputs = generator.get_production_per_second(
		state
	)
	
	for output in outputs:
		if output.resource_id == resource_id:
			total += output.amount_per_second
	
	return total


# Actual production rate for one generator.
func get_generator_actual_production_per_second(
	generator_id: String,
	resource_id: String
	) -> float:
	
	var generator = state.get_generator(
		generator_id
	)
	
	if generator == null:
		return 0.0
	
	if not generator.is_operating():
		return 0.0
	
	return get_generator_production_per_second(
		generator_id,
		resource_id
	)


# Potential consumption rate for one generator.
func get_generator_consumption_per_second(
	generator_id: String,
	resource_id: String
	) -> float:
	
	var generator = state.get_generator(
		generator_id
	)
	
	if generator == null:
		return 0.0
	
	if not generator.unlocked:
		return 0.0
	
	var total = 0.0
	
	for input in generator.definition.inputs:
		if input.resource_id != resource_id:
			continue
		
		var input_rate = generator.get_input_rate(
			input,
			state
		)
		
		total += (
			input_rate
			* generator.level
		)
	
	return total


# Actual consumption rate for one generator.
func get_generator_actual_consumption_per_second(
	generator_id: String,
	resource_id: String
	) -> float:
	
	var generator = state.get_generator(
		generator_id
	)
	
	if generator == null:
		return 0.0
	
	if not generator.is_operating():
		return 0.0
	
	return get_generator_consumption_per_second(
		generator_id,
		resource_id
	)


# ------------------------------------------------------------
# RESOURCE BREAKDOWN
# ------------------------------------------------------------

func get_resource_breakdown(
	resource_id: String
	) -> Array:
	
	var breakdown: Array = []
	
	for generator in state.get_generators().values():
		if not generator.unlocked:
			continue
		
		var production = get_generator_production_per_second(
			generator.definition.id,
			resource_id
		)
		
		var consumption = get_generator_consumption_per_second(
			generator.definition.id,
			resource_id
		)
		
		if production == 0.0 and consumption == 0.0:
			continue
		
		breakdown.append({
			"generator_id": generator.definition.id,
			"generator_name": generator.definition.display_name,
			"production": production,
			"consumption": consumption,
			"actual_production": get_generator_actual_production_per_second(
				generator.definition.id,
				resource_id
			),
			"actual_consumption": get_generator_actual_consumption_per_second(
				generator.definition.id,
				resource_id
			),
			"operating": generator.is_operating()
		})
	
	return breakdown


# ------------------------------------------------------------
# GENERATOR LISTS / GENERAL STATS
# ------------------------------------------------------------

func get_active_generators() -> Array:
	var active_generators: Array = []
	
	for generator in state.get_generators().values():
		if not generator.unlocked:
			continue
		
		if generator.level <= 0:
			continue
		
		active_generators.append(generator)
	
	return active_generators


func get_generator_stats(generator_id: String) -> Dictionary:
	var generator = state.generators.get(generator_id)
	
	if generator == null:
		return {}
	
	var data = {
		"level": generator.level,
		"unlocked": generator.unlocked,
		"operating": generator.is_operating(),
		"status": generator.get_status(),
		"cost": generator.get_cost(state),
		"cost_resource_id": generator.definition.cost_resource_id,
		"production": {},
		"actual_production": {},
		"base_production": {},
		"realm_effects": {},
		"consumption": {},
		"actual_consumption": {}
	}
	
	for output in generator.definition.outputs:
		if not output.unlocked:
			continue
		
		var resource_id = output.resource_id
		
		data["production"][resource_id] = (
			get_generator_production_per_second(
				generator_id,
				resource_id
			)
		)
		
		data["base_production"][resource_id] = (
			get_generator_base_production_per_second(
				generator_id,
				resource_id
			)
		)
		
		data["realm_effects"][resource_id] = (
			get_generator_realm_effects(
				generator_id,
				resource_id
			)
		)
		
		data["actual_production"][resource_id] = (
			get_generator_actual_production_per_second(
				generator_id,
				resource_id
			)
		)
	
	for input in generator.definition.inputs:
		var resource_id = input.resource_id
		
		data["consumption"][resource_id] = (
			get_generator_consumption_per_second(
				generator_id,
				resource_id
			)
		)
		
		data["actual_consumption"][resource_id] = (
			get_generator_actual_consumption_per_second(
				generator_id,
				resource_id
			)
		)
	
	return data


func get_generator_base_production_per_second(
	generator_id: String,
	resource_id: String
	) -> float:
	var generator = state.generators.get(generator_id)
	
	if generator == null:
		return 0.0
	
	var total = 0.0
	
	for output in generator.definition.outputs:
		if output.resource_id != resource_id:
			continue
		
		if not output.unlocked:
			continue
		
		total += output.amount_per_second * generator.level
	
	return total
	
	

func get_generator_realm_effects(
	generator_id: String,
	resource_id: String
	) -> Array[Dictionary]:
	var generator = state.generators.get(generator_id)
	
	if generator == null:
		return []
	
	if generator.level <= 0:
		return []
	
	var effects: Array[Dictionary] = []
	
	if resource_id == ResourceIds.MATTER:
		var multiplier = state.realm_effects.matter_production_multiplier
		
		if not is_equal_approx(multiplier, 1.0):
			effects.append({
				"type": "realm",
				"name": "Realm — Density",
				"multiplier": multiplier
			})
	
	elif resource_id == ResourceIds.HEAT:
		var realm_multiplier = (
			state.realm_effects.heat_production_realm_multiplier
		)
		
		if not is_equal_approx(realm_multiplier, 1.0):
			effects.append({
				"type": "realm",
				"name": "Realm — Intensity",
				"multiplier": realm_multiplier
			})
		
		var upgrade_multiplier = (
			state.realm_effects.heat_production_upgrade_multiplier
		)
		
		if not is_equal_approx(upgrade_multiplier, 1.0):
			effects.append({
				"type": "eternal_flame",
				"name": "Eternal Furnace",
				"multiplier": upgrade_multiplier
			})
	
	return effects
	
func get_generator_base_consumption_per_second(
	generator_id: String,
	resource_id: String
	) -> float:
	
	var generator = state.get_generator(
		generator_id
	)
	
	if generator == null:
		return 0.0
	
	if not generator.unlocked:
		return 0.0
	
	var total = 0.0
	
	for input in generator.definition.inputs:
		if input.resource_id != resource_id:
			continue
		
		total += (
			input.amount_per_second
			* generator.level
		)
	
	return total


# ------------------------------------------------------------
# MODIFIERS
# ------------------------------------------------------------

func get_generator_modifiers(
	generator_id: String
	) -> Array:
	
	var generator = state.get_generator(
		generator_id
	)
	
	if generator == null:
		return []
	
	var modifier_groups: Dictionary = {}
	var unsourced_modifiers: Array = []
	
	for modifier in generator.modifiers:
		var source_upgrade_id = modifier.source_upgrade_id
		
		if source_upgrade_id == "":
			unsourced_modifiers.append(
				modifier
			)
			continue
		
		var group_key = "%s|%s|%s" % [
			source_upgrade_id,
			modifier.type,
			modifier.id
		]
		
		if not modifier_groups.has(group_key):
			modifier_groups[group_key] = []
		
		modifier_groups[group_key].append(
			modifier
		)
	
	var modifiers: Array = []
	
	# --------------------------------------------------------
	# UNSOURCED / BASE MODIFIERS
	# --------------------------------------------------------
	
	for modifier in unsourced_modifiers:
		modifiers.append({
			"type": modifier.type,
			"value": modifier.multiplier,
			"dynamic": modifier.dynamic,
			"formula": modifier.dynamic_formula,
			"resource_id": modifier.dynamic_resource_id,
			"generator_id": modifier.dynamic_generator_id,
			"source_upgrade_id": modifier.source_upgrade_id,
			"current_multiplier": modifier.get_multiplier(
				state
			)
		})
	
	# --------------------------------------------------------
	# UPGRADE MODIFIERS
	# --------------------------------------------------------
	
	for group_key in modifier_groups:
		var grouped_modifiers = modifier_groups[group_key]
		
		var combined_multiplier = 1.0
		var first_modifier = grouped_modifiers[0]
		
		for modifier in grouped_modifiers:
			combined_multiplier *= modifier.get_multiplier(
				state
			)
		
		modifiers.append({
			"type": first_modifier.type,
			"value": combined_multiplier,
			"dynamic": first_modifier.dynamic,
			"formula": first_modifier.dynamic_formula,
			"resource_id": first_modifier.dynamic_resource_id,
			"generator_id": first_modifier.dynamic_generator_id,
			"source_upgrade_id": first_modifier.source_upgrade_id,
			"current_multiplier": combined_multiplier
		})
	
	return modifiers


func get_modifier_description(
	modifier: Modifier
	) -> String:
	
	var multiplier = modifier.get_multiplier(state)
	
	var source_name = "Base"
	
	if modifier.source_upgrade_id != "":
		var upgrade = state.get_upgrade(
			modifier.source_upgrade_id
		)
		
		if upgrade != null:
			source_name = upgrade.definition.display_name
	
	return "×%.2f — %s" % [
		multiplier,
		source_name
	]

func get_modifier_description_from_data(
	modifier_data: Dictionary
	) -> String:
	
	var multiplier = modifier_data.get(
		"current_multiplier",
		1.0
	)
	
	var source_name = get_modifier_source_name(
		modifier_data
	)
	
	return "×%.2f — %s" % [
		multiplier,
		source_name
	]

func get_generator_modifiers_by_type(
	generator_id: String,
	modifier_type: String
	) -> Array:
	
	var modifiers: Array = []
	
	for modifier in get_generator_modifiers(
		generator_id
	):
		if modifier["type"] != modifier_type:
			continue
		
		modifiers.append(modifier)
	
	return modifiers


func get_generator_production_modifiers(
	generator_id: String,
	resource_id: String
	) -> Array:
	
	var generator = state.get_generator(
		generator_id
	)
	
	if generator == null:
		return []
	
	var modifier_groups: Dictionary = {}
	var unsourced_modifiers: Array = []
	
	for modifier in generator.modifiers:
		if not modifier.applies_to(
			ModifierTypes.PRODUCTION,
			resource_id
		):
			continue
		
		var source_upgrade_id = modifier.source_upgrade_id
		
		# Base modifiers have no upgrade source.
		# Keep them as separate entries.
		if source_upgrade_id == "":
			unsourced_modifiers.append(
				modifier
			)
			continue
		
		if not modifier_groups.has(
			source_upgrade_id
		):
			modifier_groups[source_upgrade_id] = []
		
		modifier_groups[source_upgrade_id].append(
			modifier
		)
	
	var modifiers: Array = []
	
	# --------------------------------------------------------
	# UNSOURCED / BASE MODIFIERS
	# --------------------------------------------------------
	
	for modifier in unsourced_modifiers:
		var raw_multiplier = modifier.get_multiplier(
			state
		)
		
		var sensitivity_data = get_modifier_sensitivity_data(
			generator_id,
			modifier.id
		)
		
		var effective_multiplier = (
			1.0
			+ (
				raw_multiplier - 1.0
			) * sensitivity_data["sensitivity"]
		)
		
		modifiers.append({
			"current_multiplier": raw_multiplier,
			"effective_multiplier": effective_multiplier,
			"sensitivity": sensitivity_data["sensitivity"],
			"sensitivity_sources": sensitivity_data["sources"],
			"dynamic": modifier.dynamic,
			"formula": modifier.dynamic_formula,
			"resource_id": modifier.dynamic_resource_id,
			"source_upgrade_id": modifier.source_upgrade_id,
			"generator_id": modifier.dynamic_generator_id
		})
	
	# --------------------------------------------------------
	# UPGRADE MODIFIERS
	# --------------------------------------------------------
	
	for source_upgrade_id in modifier_groups:
		var grouped_modifiers = modifier_groups[
			source_upgrade_id
		]
		
		var raw_multiplier = 1.0
		
		var first_modifier = grouped_modifiers[0]
		
		for modifier in grouped_modifiers:
			raw_multiplier *= modifier.get_multiplier(
				state
			)
		
		var sensitivity_data = get_modifier_sensitivity_data(
			generator_id,
			first_modifier.id
		)
		
		var effective_multiplier = (
			1.0
			+ (
				raw_multiplier - 1.0
			) * sensitivity_data["sensitivity"]
		)
		
		modifiers.append({
			"current_multiplier": raw_multiplier,
			"effective_multiplier": effective_multiplier,
			"sensitivity": sensitivity_data["sensitivity"],
			"sensitivity_sources": sensitivity_data["sources"],
			"dynamic": first_modifier.dynamic,
			"formula": first_modifier.dynamic_formula,
			"resource_id": first_modifier.dynamic_resource_id,
			"source_upgrade_id": source_upgrade_id,
			"generator_id": first_modifier.dynamic_generator_id
		})
	
	return modifiers

func get_generator_input_modifiers(
	generator_id: String,
	resource_id: String
	) -> Array:
	
	var generator = state.get_generator(
		generator_id
	)
	
	if generator == null:
		return []
	
	var modifier_groups: Dictionary = {}
	var unsourced_modifiers: Array = []
	
	for modifier in generator.modifiers:
		if not modifier.applies_to(
			ModifierTypes.INPUT_DRAW,
			resource_id
		):
			continue
		
		var source_upgrade_id = modifier.source_upgrade_id
		
		if source_upgrade_id == "":
			unsourced_modifiers.append(
				modifier
			)
			continue
		
		if not modifier_groups.has(
			source_upgrade_id
		):
			modifier_groups[source_upgrade_id] = []
		
		modifier_groups[source_upgrade_id].append(
			modifier
		)
	
	var modifiers: Array = []
	
	# --------------------------------------------------------
	# UNSOURCED / BASE MODIFIERS
	# --------------------------------------------------------
	
	for modifier in unsourced_modifiers:
		modifiers.append({
			"current_multiplier": modifier.get_multiplier(
				state
			),
			"effective_multiplier": modifier.get_effective_multiplier(
				state,
				generator
			),
			"sensitivity": generator.get_modifier_sensitivity(
				modifier.id,
				state
			),
			"dynamic": modifier.dynamic,
			"formula": modifier.dynamic_formula,
			"resource_id": modifier.dynamic_resource_id,
			"generator_id": modifier.dynamic_generator_id,
			"source_upgrade_id": modifier.source_upgrade_id
		})
	
	# --------------------------------------------------------
	# UPGRADE MODIFIERS
	# --------------------------------------------------------
	
	for source_upgrade_id in modifier_groups:
		var grouped_modifiers = modifier_groups[
			source_upgrade_id
		]
		
		var raw_multiplier = 1.0
		var effective_multiplier = 1.0
		
		var first_modifier = grouped_modifiers[0]
		
		for modifier in grouped_modifiers:
			raw_multiplier *= modifier.get_multiplier(
				state
			)
			
			effective_multiplier *= (
				modifier.get_effective_multiplier(
					state,
					generator
				)
			)
		
		modifiers.append({
			"current_multiplier": raw_multiplier,
			"effective_multiplier": effective_multiplier,
			"sensitivity": generator.get_modifier_sensitivity(
				first_modifier.id,
				state
			),
			"dynamic": first_modifier.dynamic,
			"formula": first_modifier.dynamic_formula,
			"resource_id": first_modifier.dynamic_resource_id,
			"generator_id": first_modifier.dynamic_generator_id,
			"source_upgrade_id": source_upgrade_id
		})
	
	return modifiers

func get_modifier_source_name(
	modifier_data: Dictionary
	) -> String:
	
	var upgrade_id = modifier_data.get(
		"source_upgrade_id",
		""
	)
	
	if upgrade_id == "":
		return "Base"
	
	var upgrade = state.get_upgrade(
		upgrade_id
	)
	
	if upgrade == null:
		return "Unknown"
	
	return upgrade.definition.display_name


func get_modifier_effective_multiplier(
	modifier: Modifier,
	generator: Generator
	) -> float:
	
	var multiplier = modifier.get_multiplier(
		state
	)
	
	var sensitivity = generator.get_modifier_sensitivity(
		modifier.id,
		state
	)
	
	return (
		1.0
		+ (
			multiplier - 1.0
		) * sensitivity
	)

func _aggregate_modifier_data(
	modifiers: Array
	) -> Array:
	
	var aggregated: Dictionary = {}
	
	for modifier in modifiers:
		var source_upgrade_id = modifier.get(
			"source_upgrade_id",
			""
		)
		
		# Base modifiers or modifiers without a source should
		# remain separate.
		if source_upgrade_id == "":
			aggregated[
				"__base_%d" % aggregated.size()
			] = modifier
			continue
		
		if not aggregated.has(source_upgrade_id):
			var combined = modifier.duplicate()
			
			combined["current_multiplier"] = 1.0
			
			if combined.has("effective_multiplier"):
				combined["effective_multiplier"] = 1.0
			
			aggregated[source_upgrade_id] = combined
		
		var combined = aggregated[source_upgrade_id]
		
		combined["current_multiplier"] *= modifier.get(
			"current_multiplier",
			1.0
		)
		
		if combined.has("effective_multiplier"):
			combined["effective_multiplier"] = (
				combined["effective_multiplier"]
				* modifier.get(
					"effective_multiplier",
					1.0
				)
			)
	
	return aggregated.values()


func get_sensitivity_source_name(
	sensitivity: ModifierSensitivity
	) -> String:
	
	if sensitivity.source_upgrade_id == "":
		return "Base"
	
	var upgrade = state.get_upgrade(
		sensitivity.source_upgrade_id
	)
	
	if upgrade == null:
		return "Unknown"
	
	return upgrade.definition.display_name


func get_sensitivity_modifier_name(
	modifier_id: String
	) -> String:
	
	match modifier_id:
		"ashen_contamination":
			return "Ashen Contamination"
	
	return modifier_id


func get_modifier_sensitivity_data(
	generator_id: String,
	modifier_id: String
	) -> Dictionary:
	
	var generator = state.get_generator(
		generator_id
	)
	
	if generator == null:
		return {
			"sensitivity": 1.0,
			"sources": []
		}
	
	var sensitivity = generator.get_modifier_sensitivity(
		modifier_id,
		state
	)
	
	var sources: Array = []
	
	for sensitivity_modifier in generator.modifier_sensitivities:
		if sensitivity_modifier.modifier_id != modifier_id:
			continue
		
		sources.append({
			"multiplier": sensitivity_modifier.multiplier,
			"source_upgrade_id": sensitivity_modifier.source_upgrade_id
		})
	
	return {
		"sensitivity": sensitivity,
		"sources": sources
	}


func get_heat_leak_per_second() -> float:
	return state.get_heat_leak_per_second()
