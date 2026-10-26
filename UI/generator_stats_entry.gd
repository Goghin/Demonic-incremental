
class_name GeneratorStatsEntry
extends Control


@onready var header_button: Button = (
	$PanelContainer/VBoxContainer/HeaderButton
)

@onready var generator_name_label: Label = (
	$PanelContainer/VBoxContainer/HeaderButton/HeaderContainer/TopRow/GeneratorNameLabel
)

@onready var level_label: Label = (
	$PanelContainer/VBoxContainer/HeaderButton/HeaderContainer/TopRow/LevelLabel
)

@onready var production_label: VBoxContainer = (
	$PanelContainer/VBoxContainer/HeaderButton/HeaderContainer/RateRow/ProductionLabel
)

@onready var consumption_label: VBoxContainer = (
	$PanelContainer/VBoxContainer/HeaderButton/HeaderContainer/RateRow/ConsumptionLabel
)

@onready var detail_container: VBoxContainer = (
	$PanelContainer/VBoxContainer/DetailContainer
)


var state: GameState
var stats: GameStats
var generator_id: String
var expanded: bool = false

var detail_structure_signature: String = ""
var detail_rows: Array[Dictionary] = []


func _ready() -> void:
	header_button.pressed.connect(_on_header_pressed)
	_style_entry()
	detail_container.visible = false


func _style_entry() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.045, 0.055, 0.96)
	panel_style.border_color = Color(0.30, 0.21, 0.19, 1.0)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(3)
	panel_style.set_content_margin_all(6)
	$PanelContainer.add_theme_stylebox_override("panel", panel_style)

	header_button.add_theme_font_size_override("font_size", 10)
	header_button.add_theme_color_override("font_color", Color(1.0, 0.83, 0.66))
	header_button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.78))
	header_button.add_theme_color_override("font_pressed_color", Color(1.0, 0.70, 0.43))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.085, 0.06, 0.06, 1.0)
	normal.border_color = Color(0.34, 0.23, 0.20, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 7.0
	normal.content_margin_right = 7.0
	normal.content_margin_top = 5.0
	normal.content_margin_bottom = 5.0
	header_button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.15, 0.085, 0.065, 1.0)
	hover.border_color = Color(0.72, 0.38, 0.22, 1.0)
	header_button.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.22, 0.12, 0.075, 1.0)
	pressed.border_color = Color(0.95, 0.52, 0.25, 1.0)
	header_button.add_theme_stylebox_override("pressed", pressed)


func setup(
	game_state: GameState,
	game_stats: GameStats,
	game_generator_id: String
) -> void:
	state = game_state
	stats = game_stats
	generator_id = game_generator_id


func _process(_delta: float) -> void:
	if state == null or stats == null:
		return
	
	update_display()


func update_display() -> void:
	var generator = state.get_generator(generator_id)
	
	if generator == null:
		return
	
	var stats_data = stats.get_generator_stats(
		generator_id
	)
	
	update_header(
		generator,
		stats_data
	)
	
	if not expanded:
		return
	
	var structure_signature = get_detail_structure_signature(
		generator,
		stats_data
	)
	
	if structure_signature != detail_structure_signature:
		rebuild_details(
			generator,
			stats_data,
			structure_signature
		)
	
	update_detail_values(
		generator,
		stats_data
	)


func _get_minimum_size() -> Vector2:
	return $PanelContainer.get_combined_minimum_size()


func update_header(
	generator: Generator,
	stats_data: Dictionary
	) -> void:
	
	generator_name_label.text = generator.definition.display_name
	if generator.definition.id == "lava_mite_colony" and generator.is_throttled:
		generator_name_label.text += "  [THROTTLED]"
		generator_name_label.add_theme_color_override(
			"font_color",
			Color(0.95, 0.62, 0.39)
		)
	else:
		generator_name_label.remove_theme_color_override("font_color")
	
	level_label.text = "Level %d" % stats_data["level"]
	
	_update_header_rate_rows(
		production_label,
		stats_data["production"],
		"+"
	)
	_update_header_rate_rows(
		consumption_label,
		stats_data["consumption"],
		"-"
	)


func _update_header_rate_rows(
	container: VBoxContainer,
	rates: Dictionary,
	prefix: String
) -> void:
	var resource_ids: Array = rates.keys()
	var rebuild := container.get_child_count() != resource_ids.size()

	if not rebuild:
		for i in range(resource_ids.size()):
			var existing_row := container.get_child(i) as HBoxContainer
			if (
				existing_row == null
				or str(existing_row.get_meta("resource_id", "")) != str(resource_ids[i])
			):
				rebuild = true
				break

	if rebuild:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()

		for resource_value in resource_ids:
			var resource_id: String = str(resource_value)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 3)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.set_meta("resource_id", resource_id)
			container.add_child(row)

			var icon := ResourceIcon.new()
			icon.name = "ResourceIcon"
			icon.setup(resource_id, Vector2(12.0, 12.0))
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(icon)

			var value_label := Label.new()
			value_label.name = "RateLabel"
			value_label.add_theme_font_size_override("font_size", 10)
			value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(value_label)

	for i in range(resource_ids.size()):
		var resource_id: String = str(resource_ids[i])
		var row := container.get_child(i) as HBoxContainer
		var label := row.get_node("RateLabel") as Label
		label.text = "%s%s %s/s" % [
			prefix,
			NumberFormatter.format(float(rates[resource_ids[i]])),
			state.get_resource_display_name(resource_id)
		]


func get_detail_structure_signature(
	generator: Generator,
	stats_data: Dictionary
	) -> String:
	
	var signature = ""
	
	# Production resources
	signature += "production:"
	
	for resource_id in stats_data["production"]:
		signature += str(resource_id)
		signature += ";"
		
		var realm_effects = stats_data["realm_effects"].get(
			resource_id,
			[]
		)
		
		signature += "realm_effects:"
		
		for effect in realm_effects:
			signature += str(effect["name"])
			signature += ";"
		
		var modifiers = stats.get_generator_production_modifiers(
			generator.definition.id,
			resource_id
		)
		
		signature += "modifiers:"
		
		for modifier in modifiers:
			signature += str(
				stats.get_modifier_source_name(
					modifier
				)
			)
			signature += ";"
	
	# Consumption resources
	signature += "|consumption:"
	
	for resource_id in stats_data["consumption"]:
		signature += str(resource_id)
		signature += ";"
		
		var modifiers = stats.get_generator_input_modifiers(
			generator_id,
			resource_id
		)
		
		signature += "modifiers:"
		
		for modifier in modifiers:
			signature += str(
				stats.get_modifier_source_name(
					modifier
				)
			)
			signature += ";"
	
	# Misc modifiers
	signature += "|misc:"
	
	var generator_modifiers = stats.get_generator_modifiers(
		generator.definition.id
	)
	
	for modifier in generator_modifiers:
		if modifier["type"] == ModifierTypes.PRODUCTION:
			continue
		
		if modifier["type"] == ModifierTypes.INPUT_DRAW:
			continue
		
		signature += str(
			modifier["type"]
		)
		signature += ":"
		signature += str(
			stats.get_modifier_source_name(
				modifier
			)
		)
		signature += ";"
	
	# Rebuild when purchased effects or the selected operation mode changes.
	signature += "|special_effects:" + generator.operation_mode_id
	for descriptor in get_special_effect_descriptors(generator):
		signature += str(descriptor.get("key", "")) + ";"

	return signature


func rebuild_details(
	generator: Generator,
	stats_data: Dictionary,
	structure_signature: String
	) -> void:
	
	for child in detail_container.get_children():
		child.queue_free()
	
	detail_rows.clear()
	
	detail_structure_signature = structure_signature
	
	build_production_details(
		generator,
		stats_data
	)
	
	add_detail_separator()
	
	build_consumption_details(
		stats_data
	)
	
	add_detail_separator()
	
	build_modifier_details(
		generator
	)
	build_special_effect_details(generator)


func build_special_effect_details(generator: Generator) -> void:
	var descriptors := get_special_effect_descriptors(generator)
	if descriptors.is_empty():
		return

	add_detail_separator()
	add_detail_row(create_stats_label("Special Effects:", 11), "special_effect_title")
	for effect_index in range(descriptors.size()):
		var label := create_stats_label("", 10)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_detail_row(label, "special_effect", "", effect_index)


func get_special_effect_descriptors(generator: Generator) -> Array[Dictionary]:
	var descriptors: Array[Dictionary] = []

	# Event effects use the same data as the simulation. Display only purchased
	# sources and derive chance/strength from the current upgrade level.
	for effect in generator.event_effects:
		var source_upgrade: Upgrade = state.get_upgrade(effect.event_source_upgrade_id)
		if source_upgrade == null or source_upgrade.level <= 0:
			continue

		var mode_restricted := not effect.operation_mode_ids.is_empty()
		var event_applies_now := (
			not mode_restricted
			or effect.operation_mode_ids.has(generator.operation_mode_id)
		)
		var mode_text := "All modes"
		if mode_restricted:
			mode_text = _get_effect_mode_names(generator, effect.operation_mode_ids)
		descriptors.append({
			"key": "event:%s:%s:%s" % [
				effect.event_source_upgrade_id,
				effect.event_action,
				",".join(effect.operation_mode_ids)
			],
			"name": source_upgrade.definition.display_name,
			"description": _describe_event_effect(generator, effect, source_upgrade),
			"mode_text": mode_text,
			"active": event_applies_now
		})

	# Crafting critical chance lives on operation-mode data rather than an
	# UpgradeEffect, but uses the same reusable stats-section presentation.
	for mode in generator.definition.operation_modes:
		if mode.completion_critical_chance <= 0.0:
			continue
		var critical_applies_now := mode.id == generator.operation_mode_id
		var critical_chance := _get_effective_relic_critical_chance(generator, mode)
		descriptors.append({
			"key": "completion_critical:%s" % mode.id,
			"name": "Critical Crafting",
			"description": "Chance: %s%% per completed cycle to promote the crafted relic by one tier." % [
				NumberFormatter.format(critical_chance * 100.0)
			],
			"mode_text": mode.display_name,
			"active": critical_applies_now
		})

	return descriptors


func update_special_effect_label(
	label: Label,
	generator: Generator,
	effect_index: int
) -> void:
	var descriptors := get_special_effect_descriptors(generator)
	if effect_index < 0 or effect_index >= descriptors.size():
		label.text = ""
		return

	var descriptor: Dictionary = descriptors[effect_index]
	var is_active: bool = bool(descriptor.get("active", true))
	var status_prefix := "✓ " if is_active else "— "
	var mode_text := str(descriptor.get("mode_text", "All modes"))
	label.text = "%s%s: %s\n  Modes: %s%s" % [
		status_prefix,
		str(descriptor.get("name", "Special Effect")),
		str(descriptor.get("description", "")),
		mode_text,
		"" if is_active else " (inactive in current mode)"
	]
	label.add_theme_color_override(
		"font_color",
		Color(0.82, 0.78, 0.70) if is_active else Color(0.56, 0.52, 0.51)
	)


func _describe_event_effect(generator: Generator, effect: UpgradeEffect, source_upgrade: Upgrade) -> String:
	var effect_level: int = maxi(source_upgrade.level, 0)
	match effect.event_action:
		UpgradeEffectTypes.EVENT_ACTION_TRIGGER:
			var chance := _get_effective_event_chance(generator, effect, effect.event_chance * effect_level)
			return "Chance: %s%% per completed cycle to trigger %s." % [
				NumberFormatter.format(chance * 100.0),
				_get_event_display_name(generator, effect.event_id)
			]
		UpgradeEffectTypes.EVENT_ACTION_MULTIPLY_COMPLETION_OUTPUT:
			var bonus := effect.event_value * effect_level * 100.0
			var resource_name := state.get_resource_display_name(effect.event_resource_id) if effect.event_resource_id != "" else "completion output"
			var condition_text := ""
			if effect.event_condition_id != "":
				condition_text = " when %s triggers" % _get_event_display_name(generator, effect.event_condition_id)
			return "Bonus: +%s%% %s%s." % [
				NumberFormatter.format(bonus),
				resource_name,
				condition_text
			]
		UpgradeEffectTypes.EVENT_ACTION_DECREASE_GENERATOR_LEVEL:
			var chance := _get_effective_event_chance(generator, effect, effect.event_chance * effect_level)
			var levels_lost := maxi(roundi(effect.event_value), 1)
			return "Chance: %s%% per completed cycle to lose %d generator level(s)." % [
				NumberFormatter.format(chance * 100.0),
				levels_lost
			]
		_:
			return "Event action: %s." % effect.event_action.replace("_", " ")


func _get_effective_event_chance(
	generator: Generator,
	effect: UpgradeEffect,
	base_chance: float
) -> float:
	if generator == null:
		return clampf(base_chance, 0.0, 1.0)

	var chance := base_chance
	var chance_stat := ""
	if effect.event_action == UpgradeEffectTypes.EVENT_ACTION_DECREASE_GENERATOR_LEVEL:
		chance_stat = "downlevel_chance"
	elif effect.event_id == "forge_critical":
		chance_stat = "critical_chance"

	if chance_stat != "":
		for modifier in generator.modifiers:
			if not modifier.applies_to(ModifierTypes.EVENT_CHANCE, chance_stat):
				continue
			chance += modifier.get_effective_additive(state, generator)

	return clampf(chance, 0.0, 1.0)


func _get_effective_relic_critical_chance(
	generator: Generator,
	mode: GeneratorOperationMode
) -> float:
	if generator == null or mode == null:
		return 0.0

	var base_chance := mode.completion_critical_chance
	if mode.completion_random_relic_tier <= 0:
		return clampf(base_chance, 0.0, 1.0)

	var levels_above_start := maxi(
		generator.level - generator.definition.starting_level,
		0
	)
	var chance := base_chance + levels_above_start * generator.definition.level_critical_chance_bonus
	var effective_cap := maxf(
		generator.definition.level_critical_chance_cap,
		base_chance
	)
	chance = clampf(chance, 0.0, effective_cap)

	if (
		mode.id == generator.operation_mode_id
		and generator.cycle_active
		and generator.cycle_critical_chance_snapshot >= 0.0
	):
		return generator.cycle_critical_chance_snapshot

	return chance


func _get_event_display_name(generator: Generator, event_id: String) -> String:
	if event_id == UpgradeEffectTypes.EVENT_CYCLE_COMPLETED:
		return "cycle completion"
	for effect in generator.event_effects:
		if effect.event_id != event_id:
			continue
		var source_upgrade: Upgrade = state.get_upgrade(effect.event_source_upgrade_id)
		if source_upgrade != null:
			return source_upgrade.definition.display_name
	return event_id.replace("_", " ")


func _get_effect_mode_names(generator: Generator, mode_ids: Array[String]) -> String:
	var names: Array[String] = []
	for mode_id in mode_ids:
		var found := false
		for mode in generator.definition.operation_modes:
			if mode.id != mode_id:
				continue
			names.append(mode.display_name)
			found = true
			break
		if not found:
			names.append(mode_id.replace("_", " ").capitalize())
	return ", ".join(names)


func apply_modifier_color(
	label: Label,
	modifier_type: String,
	multiplier: float
	) -> void:
	
	var is_positive = false
	
	match modifier_type:
		ModifierTypes.PRODUCTION:
			is_positive = multiplier > 1.0
		
		ModifierTypes.INPUT_DRAW:
			is_positive = multiplier < 1.0
		
		ModifierTypes.COST:
			is_positive = multiplier < 1.0
		
		ModifierTypes.COST_SCALING:
			is_positive = multiplier < 1.0
		
		_:
			is_positive = multiplier > 1.0
	
	if is_equal_approx(multiplier, 1.0):
		label.remove_theme_color_override("font_color")
		return
	
	if is_positive:
		label.add_theme_color_override(
			"font_color",
			Color(0.35, 0.85, 0.45)
		)
	else:
		label.add_theme_color_override(
			"font_color",
			Color(0.9, 0.35, 0.35)
		)
		
func create_stats_label(
	text: String,
	font_size: int = 11
	) -> Label:
	
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override(
		"font_size",
		font_size
	)
	
	return label


func add_detail_separator() -> void:
	var separator = HSeparator.new()
	
	detail_container.add_child(separator)


func add_detail_row(
	label: Label,
	row_type: String,
	resource_id: String = "",
	modifier_index: int = -1
	) -> void:
	var show_resource_icon: bool = (
		not resource_id.is_empty()
		and row_type in [
			"production_base",
			"production_final",
			"consumption_base",
			"consumption_final"
		]
	)

	if show_resource_icon:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail_container.add_child(row)

		var icon := ResourceIcon.new()
		icon.setup(resource_id, Vector2(12.0, 12.0))
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)

		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
	else:
		detail_container.add_child(label)

	detail_rows.append({
		"label": label,
		"type": row_type,
		"resource_id": resource_id,
		"modifier_index": modifier_index
	})



func add_resource_separator() -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 3.0
	
	detail_container.add_child(spacer)


func build_production_details(
	generator: Generator,
	stats_data: Dictionary
	) -> void:
	
	var title = create_stats_label(
		"Production:",
		11
	)
	
	add_detail_row(
		title,
		"production_title"
	)
	
	var production_index = 0
	
	for resource_id in stats_data["production"]:
		if production_index > 0:
			add_resource_separator()
		
		production_index += 1
		
		var base_label = create_stats_label(
			"",
			11
		)
		
		add_detail_row(
			base_label,
			"production_base",
			resource_id
		)
		
		# Realm effects
		var realm_effects = stats_data["realm_effects"].get(
			resource_id,
			[]
		)
		
		for realm_index in range(realm_effects.size()):
			var realm_label = create_stats_label(
				"",
				10
			)
			
			add_detail_row(
				realm_label,
				"production_realm_effect",
				resource_id,
				realm_index
			)
		
		# Normal production modifiers
		var modifiers = stats.get_generator_production_modifiers(
			generator.definition.id,
			resource_id
		)
		
		for modifier_index in range(modifiers.size()):
			var modifier_label = create_stats_label(
				"",
				10
			)
			
			add_detail_row(
				modifier_label,
				"production_modifier",
				resource_id,
				modifier_index
			)
		
		var final_label = create_stats_label(
			"",
			11
		)
		
		add_detail_row(
			final_label,
			"production_final",
			resource_id
		)


func build_consumption_details(
	stats_data: Dictionary
	) -> void:
	
	if stats_data["consumption"].is_empty():
		return
	
	var title = create_stats_label(
		"Consumption:",
		11
	)
	
	add_detail_row(
		title,
		"consumption_title"
	)
	
	var consumption_index = 0
	
	for resource_id in stats_data["consumption"]:
		if consumption_index > 0:
			add_resource_separator()
		
		consumption_index += 1
		
		var base_label = create_stats_label(
			"",
			11
		)
		
		add_detail_row(
			base_label,
			"consumption_base",
			resource_id
		)
		
		var modifiers = stats.get_generator_input_modifiers(
			generator_id,
			resource_id
		)
		
		for modifier_index in range(modifiers.size()):
			var modifier_label = create_stats_label(
				"",
				10
			)
			
			add_detail_row(
				modifier_label,
				"consumption_modifier",
				resource_id,
				modifier_index
			)
		
		var final_label = create_stats_label(
			"",
			11
		)
		
		add_detail_row(
			final_label,
			"consumption_final",
			resource_id
		)




func build_modifier_details(
	generator: Generator
	) -> void:
	
	var modifiers = stats.get_generator_modifiers(
		generator.definition.id
	)
	
	var misc_modifiers: Array = []
	
	for modifier in modifiers:
		if modifier["type"] == ModifierTypes.PRODUCTION:
			continue
		
		if modifier["type"] == ModifierTypes.INPUT_DRAW:
			continue
		
		misc_modifiers.append(modifier)
	
	if misc_modifiers.is_empty():
		return
	
	var title = create_stats_label(
		"Misc:",
		11
	)
	
	add_detail_row(
		title,
		"modifier_title"
	)
	
	for modifier_index in range(
		misc_modifiers.size()
	):
		var label = create_stats_label(
			"",
			10
		)
		
		add_detail_row(
			label,
			"modifier",
			"",
			modifier_index
		)


func update_detail_values(
	generator: Generator,
	stats_data: Dictionary
	) -> void:
	
	for row in detail_rows:
		var label: Label = row["label"]
		var row_type: String = row["type"]
		var resource_id: String = row["resource_id"]
		var modifier_index: int = row["modifier_index"]
		
		match row_type:
			"production_base":
				update_production_base_label(
					label,
					resource_id,
					stats_data
				)
			
			"production_realm_effect":
				update_production_realm_effect_label(
					label,
					resource_id,
					modifier_index,
					stats_data
				)
			
			"production_modifier":
				update_production_modifier_label(
					label,
					generator,
					resource_id,
					modifier_index
				)
			
			"production_final":
				update_production_final_label(
					label,
					resource_id,
					stats_data
				)
			
			"consumption_base":
				update_consumption_base_label(
					label,
					resource_id
				)
			
			"consumption_modifier":
				update_consumption_modifier_label(
					label,
					resource_id,
					modifier_index
				)
			
			"consumption_final":
				update_consumption_final_label(
					label,
					resource_id,
					stats_data
				)
			
			"modifier":
				update_modifier_label(
					label,
					generator,
					modifier_index
				)
			"special_effect":
				update_special_effect_label(label, generator, modifier_index)


func update_production_base_label(
	label: Label,
	resource_id: String,
	stats_data: Dictionary
	) -> void:
	
	var resource_name = state.get_resource_display_name(
		resource_id
	)
	
	var base_production = stats_data["base_production"].get(
		resource_id,
		0.0
	)
	
	label.text = "  Base: %s %s/s" % [
		NumberFormatter.format(base_production),
		resource_name
	]


func update_production_realm_effect_label(
	label: Label,
	resource_id: String,
	effect_index: int,
	stats_data: Dictionary
	) -> void:
	
	var realm_effects = stats_data["realm_effects"].get(
		resource_id,
		[]
	)
	
	if effect_index >= realm_effects.size():
		label.text = ""
		return
	
	var effect = realm_effects[effect_index]
	var multiplier = effect["multiplier"]
	var effect_name = effect["name"]
	apply_modifier_color(
	label,
	ModifierTypes.PRODUCTION,
	multiplier
	)
	label.text = "  ×%s  %s" % [
		NumberFormatter.format(multiplier),
		effect_name
	]


func update_production_modifier_label(
	label: Label,
	generator: Generator,
	resource_id: String,
	modifier_index: int
	) -> void:
	
	var modifiers = stats.get_generator_production_modifiers(
		generator.definition.id,
		resource_id
	)
	
	if modifier_index >= modifiers.size():
		label.text = ""
		return
	
	var modifier = modifiers[modifier_index]
	
	var source_name = stats.get_modifier_source_name(
		modifier
	)
	
	var raw_multiplier = modifier["current_multiplier"]
	var effective_multiplier = modifier[
		"effective_multiplier"
	]
	apply_modifier_color(
	label,
	ModifierTypes.PRODUCTION,
	effective_multiplier
	)
	if is_equal_approx(
		raw_multiplier,
		effective_multiplier
	):
		label.text = "  ×%s  Production — %s" % [
			NumberFormatter.format(effective_multiplier),
			source_name
		]
	else:
		label.text = (
			"  ×%s  Production — %s "
			+ "(raw ×%s, sensitivity ×%s)"
		) % [
			NumberFormatter.format(effective_multiplier),
			source_name,
			NumberFormatter.format(raw_multiplier),
			NumberFormatter.format(
				modifier["sensitivity"]
			)
		]


func update_production_final_label(
	label: Label,
	resource_id: String,
	stats_data: Dictionary
	) -> void:
	
	var resource_name = state.get_resource_display_name(
		resource_id
	)
	
	var final_production = stats_data["production"][
		resource_id
	]
	
	label.text = "  Final: %s %s/s" % [
		NumberFormatter.format(final_production),
		resource_name
	]


func update_consumption_base_label(
	label: Label,
	resource_id: String
	) -> void:
	
	var resource_name = state.get_resource_display_name(
		resource_id
	)
	
	var base_consumption = (
		stats.get_generator_base_consumption_per_second(
			generator_id,
			resource_id
		)
	)
	
	label.text = "  Base: %s %s/s" % [
		NumberFormatter.format(base_consumption),
		resource_name
	]


func update_consumption_modifier_label(
	label: Label,
	resource_id: String,
	modifier_index: int
	) -> void:
	
	var modifiers = stats.get_generator_input_modifiers(
		generator_id,
		resource_id
	)
	
	if modifier_index >= modifiers.size():
		label.text = ""
		return
	
	var modifier = modifiers[modifier_index]
	
	var source_name = stats.get_modifier_source_name(
		modifier
	)
	
	var raw_multiplier = modifier["current_multiplier"]
	var effective_multiplier = modifier[
		"effective_multiplier"
	]
	var inactive_due_to_throttling := (
		_is_modifier_inactive_due_to_throttling(modifier)
	)
	apply_modifier_color(
		label,
		ModifierTypes.INPUT_DRAW,
		effective_multiplier
	)
	if is_equal_approx(
		raw_multiplier,
		effective_multiplier
	):
		label.text = "  ×%s  Input draw — %s" % [
			NumberFormatter.format(
				effective_multiplier
			),
			source_name
		]
	else:
		label.text = (
			"  ×%s  Input draw — %s "
			+ "(raw ×%s, sensitivity ×%s)"
		) % [
			NumberFormatter.format(
				effective_multiplier
			),
			source_name,
			NumberFormatter.format(
				raw_multiplier
			),
			NumberFormatter.format(
				modifier["sensitivity"]
			)
		]

	if inactive_due_to_throttling:
		label.text += "  [INACTIVE — Throttled]"
		label.add_theme_color_override(
			"font_color",
			Color(0.58, 0.55, 0.54)
		)


func _is_modifier_inactive_due_to_throttling(
	modifier: Dictionary
	) -> bool:
	var generator = state.get_generator(generator_id)
	if generator == null or not generator.is_throttled:
		return false
	if generator.definition.id != "lava_mite_colony":
		return false

	# Mirror Generator's throttling filter: only Ash-driven dynamic
	# modifiers are suppressed, except Natural Dormancy.
	if not bool(modifier.get("dynamic", false)):
		return false
	if str(modifier.get("resource_id", "")) != ResourceIds.ASH:
		return false

	var modifier_ids: Array = modifier.get("modifier_ids", [])
	return not modifier_ids.has("lava_mite_dormancy")


func update_consumption_final_label(
	label: Label,
	resource_id: String,
	stats_data: Dictionary
	) -> void:
	
	var resource_name = state.get_resource_display_name(
		resource_id
	)
	
	var final_consumption = stats_data["consumption"][
		resource_id
	]
	
	label.text = "  Final: %s %s/s" % [
		NumberFormatter.format(final_consumption),
		resource_name
	]


func update_modifier_label(
	label: Label,
	generator: Generator,
	modifier_index: int
	) -> void:
	
	var modifiers = stats.get_generator_modifiers(
		generator.definition.id
	)
	
	var misc_modifiers: Array = []
	
	for modifier in modifiers:
		if modifier["type"] == ModifierTypes.PRODUCTION:
			continue
		
		if modifier["type"] == ModifierTypes.INPUT_DRAW:
			continue
		
		misc_modifiers.append(modifier)
	
	if modifier_index >= misc_modifiers.size():
		label.text = ""
		return
	
	var modifier = misc_modifiers[modifier_index]
	var raw_multiplier: float = modifier.get(
		"current_multiplier",
		1.0
	)
	var effective_multiplier: float = modifier.get(
		"effective_multiplier",
		raw_multiplier
	)
	var sensitivity: float = modifier.get(
		"sensitivity",
		1.0
	)
	var source_name: String = stats.get_modifier_source_name(modifier)
	var sensitivity_applied: bool = not is_equal_approx(
		raw_multiplier,
		effective_multiplier
	)
	
	apply_modifier_color(
		label,
		modifier["type"],
		effective_multiplier
	)
	
	var multiplier_text := "×%s — %s" % [
		NumberFormatter.format(effective_multiplier),
		source_name
	]
	if sensitivity_applied:
		multiplier_text += " (raw ×%s, sensitivity ×%s)" % [
			NumberFormatter.format(raw_multiplier),
			NumberFormatter.format(sensitivity)
		]
	
	if modifier["type"] == ModifierTypes.CYCLE_SPEED:
		label.text = "  ×%s  Cycle speed — %s" % [
			NumberFormatter.format(effective_multiplier),
			source_name
		]
		if sensitivity_applied:
			label.text += " (raw ×%s, sensitivity ×%s)" % [
				NumberFormatter.format(raw_multiplier),
				NumberFormatter.format(sensitivity)
			]
	else:
		label.text = "  %s: %s" % [
			get_modifier_type_name(modifier["type"]),
			multiplier_text
		]


func get_modifier_type_name(
	modifier_type: String
	) -> String:
	
	match modifier_type:
		ModifierTypes.PRODUCTION:
			return "Production"
		
		ModifierTypes.COST:
			return "Cost"
		
		ModifierTypes.COST_SCALING:
			return "Cost scaling"
		
		ModifierTypes.INPUT_DRAW:
			return "Input draw"
		
		ModifierTypes.CYCLE_SPEED:
			return "Cycle speed"
	
	return modifier_type


func _on_header_pressed() -> void:
	expanded = not expanded
	detail_container.visible = expanded
	
	if expanded:
		var generator = state.get_generator(
			generator_id
		)
		
		if generator == null:
			return
		
		var stats_data = stats.get_generator_stats(
			generator_id
		)
		
		var structure_signature = (
			get_detail_structure_signature(
				generator,
				stats_data
			)
		)
		
		rebuild_details(
			generator,
			stats_data,
			structure_signature
		)
		
		update_detail_values(
			generator,
			stats_data
		)
	
	update_minimum_size()
