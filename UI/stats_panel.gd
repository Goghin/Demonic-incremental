
class_name StatsPanel
extends Control


const RESOURCE_NAME_WIDTH := 100
const RESOURCE_AMOUNT_WIDTH := 85
const RESOURCE_PRODUCTION_WIDTH := 100
const RESOURCE_CONSUMPTION_WIDTH := 105
const RESOURCE_NET_WIDTH := 80
const RESOURCE_STATISTICS_NAME_WIDTH := 100

var state: GameState
var stats: GameStats
var time_manager: TimeManager

var resource_stat_rows: Dictionary = {}
var resource_statistics_rows: Dictionary = {}
var pressure_labels: Dictionary = {}
var current_section: String = "overview"
var last_generator_id: String = ""

func _ready() -> void:
	_style_stats_panel()
	_set_active_section("overview")


func _style_stats_panel() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.035, 0.045, 0.97)
	panel_style.border_color = Color(0.34, 0.23, 0.20, 1.0)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left = 10.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_top = 9.0
	panel_style.content_margin_bottom = 9.0
	add_theme_stylebox_override("panel", panel_style)

	add_theme_color_override("font_color", Color(0.86, 0.79, 0.74))
	add_theme_color_override("font_hover_color", Color(1.0, 0.89, 0.75))
	add_theme_color_override("font_pressed_color", Color(1.0, 0.84, 0.65))

	for node_path in [
		"PanelContent/ScrollContainer/VBoxContainer/TimeStatsContainer/TimeTitleLabel",
		"PanelContent/ScrollContainer/VBoxContainer/CurrentResourcesTitleLabel",
		"PanelContent/ScrollContainer/VBoxContainer/PressureContainer/PressureTitleLabel",
		"PanelContent/ScrollContainer/VBoxContainer/ResourceHistoryTitleLabel",
		"PanelContent/ScrollContainer/VBoxContainer/GeneratorStatsTitleLabel"
	]:
		var title := get_node_or_null(node_path) as Label
		if title == null:
			continue
		title.add_theme_font_size_override("font_size", 11)
		title.add_theme_color_override("font_color", Color(1.0, 0.66, 0.36))

	for node_path in [
		"PanelContent/ScrollContainer/VBoxContainer/TimeStatsContainer/SessionTimeLabel",
		"PanelContent/ScrollContainer/VBoxContainer/TimeStatsContainer/ActiveTimeLabel",
		"PanelContent/ScrollContainer/VBoxContainer/TimeStatsContainer/OfflineTimeLabel",
		"PanelContent/ScrollContainer/VBoxContainer/TimeStatsContainer/GameTimeLabel",
		"PanelContent/ScrollContainer/VBoxContainer/TimeStatsContainer/PrestigeTimeLabel",
		"PanelContent/ScrollContainer/VBoxContainer/TimeStatsContainer/TimeScaleLabel"
	]:
		var value_label := get_node_or_null(node_path) as Label
		if value_label != null:
			value_label.add_theme_font_size_override("font_size", 10)
			value_label.add_theme_color_override("font_color", Color(0.84, 0.78, 0.74))

	var separator_style := StyleBoxLine.new()
	separator_style.color = Color(0.34, 0.23, 0.20, 0.9)
	separator_style.thickness = 1
	add_theme_stylebox_override("separator", separator_style)


func setup(
	game_state: GameState,
	game_time_manager: TimeManager
	) -> void:
	state = game_state
	stats = GameStats.new(state)
	time_manager = game_time_manager
	
	_setup_resource_stats()
	_setup_resource_statistics()
	_setup_pressure_rows()

func _process(_delta: float) -> void:
	if stats == null or time_manager == null:
		return
	
	update_time_stats()
	update_resource_stats()
	update_resource_statistics()
	update_pressure_stats()
	update_generator_stats()

func _set_active_section(section_id: String) -> void:
	current_section = section_id
	var section_nodes := {
		"overview": ["CurrentResourcesTitleLabel", "ResourceStatsContainer", "ResourceSectionSeparator"],
		"effects": ["PressureContainer", "PressureSectionSeparator"],
		"generators": ["GeneratorStatsTitleLabel", "GeneratorStatsContainer"],
		"history": ["ResourceHistoryTitleLabel", "ResourceStatisticsContainer", "HistorySectionSeparator"],
		"time": ["TimeStatsContainer", "TimeSectionSeparator"]
	}
	for section_key in section_nodes:
		for node_name in section_nodes[section_key]:
			var node := $PanelContent/ScrollContainer/VBoxContainer.get_node_or_null(node_name) as Control
			if node != null:
				node.visible = section_key == section_id
	for button_name in ["OverviewButton", "EffectsButton", "GeneratorsButton", "HistoryButton", "TimeButton"]:
		var button := $PanelContent/SectionNavigation.get_node(button_name) as Button
		var button_section: String = button_name.trim_suffix("Button").to_lower()
		button.button_pressed = button_section == section_id
		button.add_theme_font_size_override("font_size", 9)
		button.focus_mode = Control.FOCUS_NONE
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color(0.19, 0.105, 0.075, 1.0) if button.button_pressed else Color(0.075, 0.06, 0.075, 0.98)
		button_style.border_color = Color(0.95, 0.48, 0.20, 1.0) if button.button_pressed else Color(0.28, 0.20, 0.19, 1.0)
		button_style.set_border_width_all(2 if button.button_pressed else 1)
		button_style.set_corner_radius_all(3)
		button_style.content_margin_left = 3.0
		button_style.content_margin_right = 3.0
		button_style.content_margin_top = 4.0
		button_style.content_margin_bottom = 4.0
		button.add_theme_stylebox_override("normal", button_style)
		var hover_style := button_style.duplicate() as StyleBoxFlat
		hover_style.bg_color = button_style.bg_color.lightened(0.10)
		hover_style.border_color = button_style.border_color.lightened(0.10)
		button.add_theme_stylebox_override("hover", hover_style)
		button.add_theme_color_override(
			"font_color",
			Color(1.0, 0.82, 0.62) if button.button_pressed else Color(0.82, 0.75, 0.70)
		)
	$PanelContent/ScrollContainer.scroll_vertical = 0


func _on_overview_button_pressed() -> void:
	_set_active_section("overview")


func _on_effects_button_pressed() -> void:
	_set_active_section("effects")


func _on_generators_button_pressed() -> void:
	_set_active_section("generators")


func _on_history_button_pressed() -> void:
	_set_active_section("history")


func _on_time_button_pressed() -> void:
	_set_active_section("time")


func open_generator_stats(generator_id: String) -> void:
	if generator_id.is_empty():
		_set_active_section("generators")
		return
	last_generator_id = generator_id
	_set_active_section("generators")
	ensure_generator_stats()
	await get_tree().process_frame
	var entry := $PanelContent/ScrollContainer/VBoxContainer/GeneratorStatsContainer.get_node_or_null(generator_id) as GeneratorStatsEntry
	if entry == null:
		return
	entry.expanded = true
	entry.update_display()
	await get_tree().process_frame
	$PanelContent/ScrollContainer.ensure_control_visible(entry)


func _setup_resource_stats() -> void:
	var container = (
		$PanelContent/ScrollContainer/VBoxContainer/ResourceStatsContainer
	)
	
	for child in container.get_children():
		child.queue_free()
	
	# Header
	var header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 24)
	
	container.add_child(header)
	
	header.add_child(
		_create_column_label(
			"RESOURCE",
			RESOURCE_NAME_WIDTH,
			HORIZONTAL_ALIGNMENT_LEFT,
			11
		)
	)
	
	header.add_child(
		_create_column_label(
			"AMOUNT",
			RESOURCE_AMOUNT_WIDTH,
			HORIZONTAL_ALIGNMENT_RIGHT,
			11
		)
	)
	
	header.add_child(
		_create_column_label(
			"PRODUCTION",
			RESOURCE_PRODUCTION_WIDTH,
			HORIZONTAL_ALIGNMENT_RIGHT,
			11
		)
	)
	
	header.add_child(
		_create_column_label(
			"CONSUMPTION",
			RESOURCE_CONSUMPTION_WIDTH,
			HORIZONTAL_ALIGNMENT_RIGHT,
			11
		)
	)
	
	header.add_child(
		_create_column_label(
			"NET",
			RESOURCE_NET_WIDTH,
			HORIZONTAL_ALIGNMENT_RIGHT,
			11
		)
	)
	
	# Resource rows
	for resource in state.get_resources().values():
		var resource_id = resource.definition.id
		
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 22)
		
		container.add_child(row)
		
		var name_container := HBoxContainer.new()
		name_container.custom_minimum_size = Vector2(RESOURCE_NAME_WIDTH, 0)
		name_container.add_theme_constant_override("separation", 4)
		name_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var resource_icon := ResourceIcon.new()
		resource_icon.setup(resource_id, Vector2(14.0, 14.0))
		resource_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_container.add_child(resource_icon)

		var name_label := _create_column_label(
			resource.definition.display_name,
			RESOURCE_NAME_WIDTH - 18,
			HORIZONTAL_ALIGNMENT_LEFT,
			11
		)
		name_container.add_child(name_label)
		
		var amount_label = _create_column_label(
			"",
			RESOURCE_AMOUNT_WIDTH,
			HORIZONTAL_ALIGNMENT_RIGHT,
			11
		)
		
		var production_label = _create_column_label(
			"",
			RESOURCE_PRODUCTION_WIDTH,
			HORIZONTAL_ALIGNMENT_RIGHT,
			11
		)
		
		var consumption_label = _create_column_label(
			"",
			RESOURCE_CONSUMPTION_WIDTH,
			HORIZONTAL_ALIGNMENT_RIGHT,
			11
		)
		
		var net_label = _create_column_label(
			"",
			RESOURCE_NET_WIDTH,
			HORIZONTAL_ALIGNMENT_RIGHT,
			11
		)
		
		row.add_child(name_container)
		row.add_child(amount_label)
		row.add_child(production_label)
		row.add_child(consumption_label)
		row.add_child(net_label)
		
		resource_stat_rows[resource_id] = {
			"name": name_label,
			"amount": amount_label,
			"production": production_label,
			"consumption": consumption_label,
			"net": net_label
		}

func _setup_resource_statistics() -> void:
	var container = (
		$PanelContent/ScrollContainer/VBoxContainer/ResourceStatisticsContainer
	)
	
	for child in container.get_children():
		child.queue_free()
	
	var is_first_resource := true

	for resource in state.get_resources().values():
		var resource_id = resource.definition.id

		# Separate each resource's history from the previous one.
		if not is_first_resource:
			var resource_separator = HSeparator.new()
			container.add_child(resource_separator)

		is_first_resource = false
		
		# Resource identity for this resource's history.
		var name_container := HBoxContainer.new()
		name_container.custom_minimum_size = Vector2(RESOURCE_STATISTICS_NAME_WIDTH, 0)
		name_container.add_theme_constant_override("separation", 4)
		name_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var resource_icon := ResourceIcon.new()
		resource_icon.setup(resource_id, Vector2(14.0, 14.0))
		resource_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_container.add_child(resource_icon)

		var name_label := _create_column_label(
			resource.definition.display_name,
			RESOURCE_STATISTICS_NAME_WIDTH - 18,
			HORIZONTAL_ALIGNMENT_LEFT,
			11
		)
		name_container.add_child(name_label)
		
		# Section containing This Realm and All Realms
		var stats_container = VBoxContainer.new()
		stats_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		
		var this_realm_label = Label.new()
		this_realm_label.text = "THIS REALM"
		this_realm_label.add_theme_color_override("font_color", Color(1.0, 0.70, 0.40))
		this_realm_label.add_theme_font_size_override(
			"font_size",
			10
		)
		
		var this_realm_values = Label.new()
		this_realm_values.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		this_realm_values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		this_realm_values.custom_minimum_size.x = 0.0
		this_realm_values.add_theme_font_size_override(
			"font_size",
			11
		)
		
		var all_realms_label = Label.new()
		all_realms_label.text = "ALL REALMS"
		all_realms_label.add_theme_color_override("font_color", Color(0.78, 0.67, 0.59))
		all_realms_label.add_theme_font_size_override(
			"font_size",
			10
		)
		
		var all_realms_values = Label.new()
		all_realms_values.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		all_realms_values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		all_realms_values.custom_minimum_size.x = 0.0
		all_realms_values.add_theme_font_size_override(
			"font_size",
			11
		)
		
		stats_container.add_child(
			this_realm_label
		)
		stats_container.add_child(
			this_realm_values
		)

		# Visually distinguish this realm's history from lifetime totals.
		var realm_separator = HSeparator.new()
		stats_container.add_child(realm_separator)

		stats_container.add_child(
			all_realms_label
		)
		stats_container.add_child(
			all_realms_values
		)
		
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0, 0)
		row.add_theme_constant_override("separation", 10)
		
		row.add_child(name_container)
		row.add_child(stats_container)
		
		container.add_child(row)
		
		resource_statistics_rows[resource_id] = {
			"this_realm": this_realm_values,
			"all_realms": all_realms_values
		}


func _create_column_label(
	text: String,
	width: float,
	alignment: HorizontalAlignment,
	font_size: int
	) -> Label:
	var label = Label.new()
	
	label.text = text
	label.custom_minimum_size = Vector2(
		width,
		0
	)
	
	label.size_flags_horizontal = (
		Control.SIZE_SHRINK_BEGIN
	)
	
	label.horizontal_alignment = alignment
	label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.75, 0.49) if text in ["RESOURCE", "AMOUNT", "PRODUCTION", "CONSUMPTION", "NET"] else Color(0.86, 0.79, 0.74)
	)
	
	label.add_theme_font_size_override(
		"font_size",
		font_size
	)
	
	return label

func update_resource_statistics() -> void:
	for resource in state.get_resources().values():
		var resource_id = resource.definition.id

		if not resource_statistics_rows.has(resource_id):
			continue

		var row = resource_statistics_rows[resource_id]

		var current_run_statistics = (
			state.current_run_statistics
		)

		var lifetime_statistics = (
			state.resource_statistics
		)

		var this_realm_text = (
			"Produced: %s    Consumed: %s\nLost: %s    Highest: %s"
			% [
				NumberFormatter.format(
					current_run_statistics.get_total_produced(
						resource_id
					)
				),
				NumberFormatter.format(
					current_run_statistics.get_total_consumed(
						resource_id
					)
				),
				NumberFormatter.format(
					current_run_statistics.get_total_lost(
						resource_id
					)
				),
				NumberFormatter.format(
					current_run_statistics.get_highest_amount(
						resource_id
					)
				)
			]
		)

		var all_realms_text = (
			"Produced: %s    Consumed: %s\nLost: %s    Highest: %s"
			% [
				NumberFormatter.format(
					lifetime_statistics.get_total_produced(
						resource_id
					)
				),
				NumberFormatter.format(
					lifetime_statistics.get_total_consumed(
						resource_id
					)
				),
				NumberFormatter.format(
					lifetime_statistics.get_total_lost(
						resource_id
					)
				),
				NumberFormatter.format(
					lifetime_statistics.get_highest_amount(
						resource_id
					)
				)
			]
		)
		if resource_id == ResourceIds.HEAT:
			all_realms_text += "\nOverflow: %s" % NumberFormatter.format(
				lifetime_statistics.get_total_overflow()
			)

		if resource_id == ResourceIds.MATTER:
			all_realms_text += "\nDecayed: %s" % NumberFormatter.format(
				lifetime_statistics.get_total_matter_decayed()
			)


		row["this_realm"].text = this_realm_text
		row["all_realms"].text = all_realms_text
		
func update_time_stats() -> void:
	$PanelContent/ScrollContainer/VBoxContainer/TimeStatsContainer/SessionTimeLabel.text = (
		"This Session: %s"
		% format_time(time_manager.session_time)
	)
	
	$PanelContent/ScrollContainer/VBoxContainer/TimeStatsContainer/ActiveTimeLabel.text = (
		"Active Time: %s"
		% format_time(time_manager.active_time)
	)
	
	$PanelContent/ScrollContainer/VBoxContainer/TimeStatsContainer/OfflineTimeLabel.text = (
		"Offline Time: %s"
		% format_time(time_manager.offline_time)
	)
	
	$PanelContent/ScrollContainer/VBoxContainer/TimeStatsContainer/GameTimeLabel.text = (
		"Game Time: %s"
		% format_time(time_manager.game_time)
	)
	
	$PanelContent/ScrollContainer/VBoxContainer/TimeStatsContainer/PrestigeTimeLabel.text = (
		"Since Prestige: %s"
		% format_time(time_manager.prestige_time)
	)
	
	$PanelContent/ScrollContainer/VBoxContainer/TimeStatsContainer/TimeScaleLabel.text = (
		"Time Speed: ×%s"
		% NumberFormatter.format(time_manager.time_scale)
	)



func format_time(seconds: float) -> String:
	var total_seconds: int = int(seconds)

	var days: int = floori(float(total_seconds) / 86400.0)
	var hours: int = floori(float(total_seconds % 86400) / 3600.0)
	var minutes: int = floori(float(total_seconds % 3600) / 60.0)
	var remaining_seconds: int = total_seconds % 60

	if days > 0:
		return "%dd %02dh %02dm %02ds" % [
			days,
			hours,
			minutes,
			remaining_seconds
		]

	if hours > 0:
		return "%dh %02dm %02ds" % [
			hours,
			minutes,
			remaining_seconds
		]

	if minutes > 0:
		return "%dm %02ds" % [
			minutes,
			remaining_seconds
		]

	return "%ds" % remaining_seconds


func update_resource_stats() -> void:
	for resource in state.get_resources().values():
		var resource_id = resource.definition.id
		
		if not resource_stat_rows.has(resource_id):
			continue
		
		var row = resource_stat_rows[resource_id]
		
		var amount = state.get_resource_amount(
			resource_id
		)
		
		var production = (
			stats.get_resource_actual_production_per_second(
				resource_id
			)
		)
		
		var consumption = (
			stats.get_resource_actual_consumption_per_second(
				resource_id
			)
		)
		
		var net = production - consumption
		
		row["amount"].text = NumberFormatter.format(
			amount
		)
		
		row["production"].text = "+%s /s" % (
			NumberFormatter.format(production)
		)
		
		row["consumption"].text = "-%s /s" % (
			NumberFormatter.format(consumption)
		)
		
		row["net"].text = "%+s /s" % (
			NumberFormatter.format(net)
		)

		var net_color := Color(0.68, 0.68, 0.65)
		if net > 0.0:
			net_color = Color(0.58, 0.84, 0.60)
		elif net < 0.0:
			net_color = Color(0.96, 0.51, 0.43)
		if resource_id == ResourceIds.ASH:
			if net > 0.0:
				net_color = Color(0.96, 0.51, 0.43)
			elif net < 0.0:
				net_color = Color(0.58, 0.84, 0.60)
		row["net"].add_theme_color_override("font_color", net_color)
		row["production"].add_theme_color_override("font_color", Color(0.68, 0.84, 0.65))
		row["consumption"].add_theme_color_override("font_color", Color(0.93, 0.64, 0.53))


func update_generator_stats() -> void:
	ensure_generator_stats()


func ensure_generator_stats() -> void:
	for generator in state.get_generators().values():
		if not generator.unlocked:
			continue
		
		var generator_id = generator.definition.id
		
		if $PanelContent/ScrollContainer/VBoxContainer/GeneratorStatsContainer.has_node(
			generator_id
		):
			continue
		
		var entry = preload(
			"res://UI/GeneratorStatsEntry.tscn"
		).instantiate()
		
		entry.name = generator_id
		
		$PanelContent/ScrollContainer/VBoxContainer/GeneratorStatsContainer.add_child(
			entry
		)
		
		entry.setup(
			state,
			stats,
			generator_id
		)

func _setup_pressure_rows() -> void:
	var container: VBoxContainer = $PanelContent/ScrollContainer/VBoxContainer/PressureContainer
	var title: Label = container.get_node("PressureTitleLabel")
	title.text = "EFFECTS"

	for child in container.get_children():
		if child == title:
			continue
		container.remove_child(child)
		child.queue_free()

	pressure_labels.clear()

	_add_effect_section(container, "HEAT")
	_add_effect_row(container, "heat_threshold", "Overflow Threshold: 0", ResourceIds.HEAT)
	_add_effect_row(container, "heat_rate", "Overflow Rate: 0 /s", ResourceIds.HEAT)
	_add_effect_row(container, "overflow_this_realm", "Overflow This Realm: 0", ResourceIds.HEAT)

	_add_effect_section(container, "MATTER")
	_add_effect_row(container, "matter_threshold", "Decay Threshold: 0 Matter", ResourceIds.MATTER)
	_add_effect_row(container, "matter_decay", "Decay Rate: 0 Matter/s → 0 Heat/s", ResourceIds.MATTER)
	_add_effect_row(container, "matter_decayed_this_realm", "Decayed This Realm: 0 Matter", ResourceIds.MATTER)
	
	_add_effect_section(container, "ASH CONTAMINATION")
	_add_effect_row(container, "ash_contamination", "Ash Contamination: ×1", ResourceIds.ASH)

	_add_effect_section(container, "CRYSTALLIZED FLAME")
	_add_effect_row(container, "flame_raw_multiplier", "Raw Heat Production Multiplier: ×1", ResourceIds.CRYSTALLIZED_FLAME)
	_add_effect_row(container, "flame_penalty", "Heat Production Penalty: 0%", ResourceIds.CRYSTALLIZED_FLAME)
	_add_effect_row(container, "overflow_bonus", "Overflow Counting Multiplier: ×1", ResourceIds.CRYSTALLIZED_FLAME)

	_add_effect_section(container, "ESSENCE")
	_add_effect_row(container, "essence_hunger", "Lava Mite Hunger: ×1", ResourceIds.ESSENCE)
	_add_effect_row(container, "essence_resistance", "Crystallization Resistance: 0%", ResourceIds.ESSENCE)
	_add_effect_row(container, "essence_final_multiplier", "Final Heat Production Multiplier: ×1", ResourceIds.ESSENCE)

	_add_effect_section(container, "NEXUM")
	_add_effect_row(container, "nexum_placeholder", "No effects yet", ResourceIds.NEXUM)


func _add_effect_section(container: VBoxContainer, heading: String) -> void:
	var label := Label.new()
	label.text = heading
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1.0, 0.66, 0.36))
	container.add_child(label)


func _add_effect_row(
	container: VBoxContainer,
	key: String,
	initial_text: String,
	resource_id: String
	) -> void:
	var row := HBoxContainer.new()
	row.name = key.capitalize().replace(" ", "") + "Row"
	row.add_theme_constant_override("separation", 5)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var icon := ResourceIcon.new()
	icon.setup(resource_id, Vector2(14.0, 14.0))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var label := Label.new()
	label.name = key.capitalize().replace(" ", "") + "Label"
	label.text = initial_text
	label.add_theme_font_size_override("font_size", 10)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	container.add_child(row)
	pressure_labels[key] = label


func update_pressure_stats() -> void:
	var overflow_rate := state.get_heat_leak_per_second()
	var matter_decay := state.get_matter_decay_per_second()
	var ash_contamination_multiplier := stats.get_raw_resource_modifier_multiplier(
		"ashen_contamination",
		ModifierTypes.PRODUCTION,
		""
	)

	var flame_data := stats.get_crystallization_modifier_data()
	var essence_data := stats.get_essence_influence_data()
	var heat_leak_threshold := state.realm_effects.heat_leak_threshold
	var matter_decay_threshold := state.realm_effects.matter_decay_threshold

	pressure_labels["heat_threshold"].text = (
		"Overflow Threshold: %s Heat"
		% NumberFormatter.format(heat_leak_threshold)
	)
	pressure_labels["heat_rate"].text = (
		"Overflow Rate: %s Heat/s"
		% NumberFormatter.format(overflow_rate)
	)
	pressure_labels["overflow_this_realm"].text = (
		"Overflow This Realm: %s"
		% NumberFormatter.format(state.total_overflow_this_prestige)
	)
	pressure_labels["matter_threshold"].text = (
		"Decay Threshold: %s Matter"
		% NumberFormatter.format(matter_decay_threshold)
	)
	pressure_labels["matter_decay"].text = (
		"Decay Rate: %s Matter/s → %s Heat/s"
		% [
			NumberFormatter.format(matter_decay),
			NumberFormatter.format(matter_decay)
		]
	)
	pressure_labels["matter_decayed_this_realm"].text = (
		"Decayed This Realm: %s Matter"
		% NumberFormatter.format(state.total_matter_decayed_this_prestige)
	)
	pressure_labels["ash_contamination"].text = (
		"Ash Contamination: ×%s"
		% NumberFormatter.format(ash_contamination_multiplier)
	)
	var raw_flame_multiplier: float = float(flame_data["raw_multiplier"])
	var raw_flame_penalty_percent: float = (1.0 - raw_flame_multiplier) * 100.0
	if raw_flame_multiplier > 0.0 and raw_flame_multiplier < 0.0001:
		pressure_labels["flame_raw_multiplier"].text = (
			"Raw Heat Production: ~1 in %s of normal output"
			% NumberFormatter.format(1.0 / raw_flame_multiplier)
		)
	else:
		pressure_labels["flame_raw_multiplier"].text = (
			"Raw Heat Production Multiplier: ×%s"
			% NumberFormatter.format(raw_flame_multiplier)
		)
	pressure_labels["flame_penalty"].text = (
		"Heat Production Penalty: %s%%"
		% NumberFormatter.format(raw_flame_penalty_percent)
	)
	pressure_labels["overflow_bonus"].text = (
		"Overflow Counting Multiplier: ×%s"
		% NumberFormatter.format(pow(1.25, state.get_resource_amount(ResourceIds.CRYSTALLIZED_FLAME)))
	)
	pressure_labels["essence_hunger"].text = (
		"Lava Mite Hunger: ×%s"
		% NumberFormatter.format(essence_data["hunger_multiplier"])
	)
	pressure_labels["essence_resistance"].text = (
		"Crystallization Resistance: %s%%"
		% NumberFormatter.format(flame_data["essence_resistance_percent"])
	)
	var effective_multiplier: float = float(flame_data["effective_multiplier"])
	if effective_multiplier > 0.0 and effective_multiplier < 0.0001:
		pressure_labels["essence_final_multiplier"].text = (
			"Final Heat Production: ~1 in %s of normal output"
			% NumberFormatter.format(1.0 / effective_multiplier)
		)
	else:
		pressure_labels["essence_final_multiplier"].text = (
			"Final Heat Production Multiplier: ×%s"
			% NumberFormatter.format(effective_multiplier)
		)
	pressure_labels["nexum_placeholder"].text = "No effects yet"
