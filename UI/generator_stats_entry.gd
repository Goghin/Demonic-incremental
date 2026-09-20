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
	
	var stats_data = stats.get_generator_stats(generator_id)
	
	update_header(generator, stats_data)
	update_details(generator, stats_data)

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


func update_details(
	generator: Generator,
	stats_data: Dictionary
	) -> void:
	
	for child in detail_container.get_children():
		child.queue_free()
	
	if not expanded:
		return
	
	add_production_details(
		generator,
		stats_data
	)
	
	add_consumption_details(
		stats_data
	)
	
	add_modifier_details(
		generator
	)
	
	add_sensitivity_details(
		generator
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


func add_production_details(
	generator: Generator,
	stats_data: Dictionary
	) -> void:
	
	var title = create_stats_label(
		"Production:",
		11
	)
	detail_container.add_child(title)
	
	for resource_id in stats_data["production"]:
		var resource_name = state.get_resource_display_name(
			resource_id
		)
		
		var base_production = stats_data["base_production"].get(
			resource_id,
			0.0
		)
		
		var final_production = stats_data["production"][resource_id]
		
		var base_label = create_stats_label(
			"  Base: %s %s/s" % [
				NumberFormatter.format(base_production),
				resource_name
			],
			11
		)
		
		detail_container.add_child(base_label)
		
		var modifiers = stats.get_generator_production_modifiers(
			generator.definition.id,
			resource_id
		)
		
		for modifier in modifiers:
			var modifier_label = create_stats_label(
				"",
				11
			)
			
			var source_name = stats.get_modifier_source_name(
				modifier
			)
			
			var raw_multiplier = modifier["current_multiplier"]
			var effective_multiplier = modifier[
				"effective_multiplier"
			]
			
			if is_equal_approx(
				raw_multiplier,
				effective_multiplier
			):
				modifier_label.text = "  ×%s  Production — %s" % [
					NumberFormatter.format(effective_multiplier),
					source_name
				]
			else:
				modifier_label.text = (
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
			
			detail_container.add_child(modifier_label)
		
		var final_label = create_stats_label(
			"  Final: %s %s/s" % [
				NumberFormatter.format(final_production),
				resource_name
			],
			11
		)
		
		detail_container.add_child(final_label)


func add_consumption_details(
	stats_data: Dictionary
	) -> void:
	
	if stats_data["consumption"].is_empty():
		return
	
	var title = create_stats_label(
		"Consumption:",
		11
	)
	detail_container.add_child(title)
	
	for resource_id in stats_data["consumption"]:
		var resource_name = state.get_resource_display_name(
			resource_id
		)
		
		var base_consumption = (
			stats.get_generator_base_consumption_per_second(
				generator_id,
				resource_id
			)
		)
		
		var final_consumption = stats_data["consumption"][
			resource_id
		]
		
		var base_label = create_stats_label(
			"  Base: %s %s/s" % [
				NumberFormatter.format(base_consumption),
				resource_name
			],
			11
		)
		
		detail_container.add_child(base_label)
		
		var modifiers = stats.get_generator_input_modifiers(
			generator_id,
			resource_id
		)
		
		for modifier in modifiers:
			var source_name = stats.get_modifier_source_name(
				modifier
			)
			
			var modifier_label = create_stats_label(
				"  ×%s  Input draw — %s" % [
					NumberFormatter.format(
						modifier["current_multiplier"]
					),
					source_name
				],
				11
			)
			
			detail_container.add_child(modifier_label)
		
		var final_label = create_stats_label(
			"  Final: %s %s/s" % [
				NumberFormatter.format(final_consumption),
				resource_name
			],
			11
		)
		
		detail_container.add_child(final_label)


func add_modifier_details(
	generator: Generator
	) -> void:
	
	var modifiers = stats.get_generator_modifiers(
		generator.definition.id
	)
	
	if modifiers.is_empty():
		return
	
	var title = create_stats_label(
		"Modifiers:",
		11
	)
	detail_container.add_child(title)
	
	for modifier in modifiers:
		var label = create_stats_label(
			"  %s: %s" % [
				get_modifier_type_name(
					modifier["type"]
				),
				stats.get_modifier_description_from_data(
					modifier
				)
			],
			11
		)
		
		detail_container.add_child(label)


func add_sensitivity_details(
	generator: Generator
	) -> void:
	
	if generator.modifier_sensitivities.is_empty():
		return
	
	var title = Label.new()
	title.add_theme_font_size_override(
		"font_size",
		11
	)
	title.text = "Sensitivities:"
	detail_container.add_child(title)
	
	for sensitivity in generator.modifier_sensitivities:
		var label = Label.new()
		label.add_theme_font_size_override(
			"font_size",
			11
		)
		
		var source_name = stats.get_sensitivity_source_name(
			sensitivity
		)
		
		label.text = "  %s: ×%s — %s" % [
			stats.get_sensitivity_modifier_name(
				sensitivity.modifier_id
			),
			NumberFormatter.format(
				sensitivity.multiplier
			),
			source_name
		]
		
		detail_container.add_child(label)


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
	
	update_display()
	
	update_minimum_size()
