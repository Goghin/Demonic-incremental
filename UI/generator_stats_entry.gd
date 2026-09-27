
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

@onready var production_label: Label = (
	$PanelContainer/VBoxContainer/HeaderButton/HeaderContainer/RateRow/ProductionLabel
)

@onready var consumption_label: Label = (
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
	
	detail_container.visible = false


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
	
	level_label.text = "Level %d" % stats_data["level"]
	
	var production_text = ""
	
	for resource_id in stats_data["production"]:
		var production = stats_data["production"][resource_id]
		var resource_name = state.get_resource_display_name(
			resource_id
		)
		
		if production_text != "":
			production_text += "\n"
		
		production_text += "+%s %s/s" % [
			NumberFormatter.format(production),
			resource_name
		]
	
	production_label.text = production_text
	
	var consumption_text = ""
	
	for resource_id in stats_data["consumption"]:
		var consumption = stats_data["consumption"][resource_id]
		var resource_name = state.get_resource_display_name(
			resource_id
		)
		
		if consumption_text != "":
			consumption_text += "\n"
		
		consumption_text += "-%s %s/s" % [
			NumberFormatter.format(consumption),
			resource_name
		]
	
	consumption_label.text = consumption_text


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
		
		var resource_name = state.get_resource_display_name(
			resource_id
		)
		
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
	apply_modifier_color(
	label,
	modifier["type"],
	modifier["current_multiplier"]
	)
	label.text = "  %s: %s" % [
		get_modifier_type_name(
			modifier["type"]
		),
		stats.get_modifier_description_from_data(
			modifier
		)
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
