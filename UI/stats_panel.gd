
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

func _setup_resource_stats() -> void:
	var container = (
		$ScrollContainer/VBoxContainer/ResourceStatsContainer
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
		$ScrollContainer/VBoxContainer/ResourceStatisticsContainer
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
		stats_container.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		
		var this_realm_label = Label.new()
		this_realm_label.text = "This Realm"
		this_realm_label.add_theme_font_size_override(
			"font_size",
			10
		)
		
		var this_realm_values = Label.new()
		this_realm_values.autowrap_mode = TextServer.AUTOWRAP_OFF
		this_realm_values.add_theme_font_size_override(
			"font_size",
			11
		)
		
		var all_realms_label = Label.new()
		all_realms_label.text = "All Realms"
		all_realms_label.add_theme_font_size_override(
			"font_size",
			10
		)
		
		var all_realms_values = Label.new()
		all_realms_values.autowrap_mode = TextServer.AUTOWRAP_OFF
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
		row.custom_minimum_size = Vector2(0, 90)
		
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


		row["this_realm"].text = this_realm_text
		row["all_realms"].text = all_realms_text
		
func update_time_stats() -> void:
	$ScrollContainer/VBoxContainer/TimeStatsContainer/SessionTimeLabel.text = (
		"This Session: %s"
		% format_time(time_manager.session_time)
	)
	
	$ScrollContainer/VBoxContainer/TimeStatsContainer/ActiveTimeLabel.text = (
		"Active Time: %s"
		% format_time(time_manager.active_time)
	)
	
	$ScrollContainer/VBoxContainer/TimeStatsContainer/OfflineTimeLabel.text = (
		"Offline Time: %s"
		% format_time(time_manager.offline_time)
	)
	
	$ScrollContainer/VBoxContainer/TimeStatsContainer/GameTimeLabel.text = (
		"Game Time: %s"
		% format_time(time_manager.game_time)
	)
	
	$ScrollContainer/VBoxContainer/TimeStatsContainer/PrestigeTimeLabel.text = (
		"Since Prestige: %s"
		% format_time(time_manager.prestige_time)
	)
	
	$ScrollContainer/VBoxContainer/TimeStatsContainer/TimeScaleLabel.text = (
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


func update_generator_stats() -> void:
	ensure_generator_stats()


func ensure_generator_stats() -> void:
	for generator in state.get_generators().values():
		if not generator.unlocked:
			continue
		
		var generator_id = generator.definition.id
		
		if $ScrollContainer/VBoxContainer/GeneratorStatsContainer.has_node(
			generator_id
		):
			continue
		
		var entry = preload(
			"res://UI/GeneratorStatsEntry.tscn"
		).instantiate()
		
		entry.name = generator_id
		
		$ScrollContainer/VBoxContainer/GeneratorStatsContainer.add_child(
			entry
		)
		
		entry.setup(
			state,
			stats,
			generator_id
		)

func _setup_pressure_rows() -> void:
	var container: VBoxContainer = $ScrollContainer/VBoxContainer/PressureContainer
	var row_configs: Array[Dictionary] = [
		{"key": "heat_threshold", "label": "HeatLeakageThresholdLabel", "resources": [ResourceIds.HEAT]},
		{"key": "heat_rate", "label": "HeatLeakageLabel", "resources": [ResourceIds.HEAT]},
		{"key": "overflow_multiplier", "label": "OverflowMultiplierLabel", "resources": [ResourceIds.CRYSTALLIZED_FLAME]},
		{"key": "overflow_this_realm", "label": "OverflowThisRealmLabel", "resources": [ResourceIds.HEAT]},
		{"key": "overflow_all_realms", "label": "OverflowAllRealmsLabel", "resources": [ResourceIds.HEAT]},
		{"key": "matter_threshold", "label": "MatterDecayThresholdLabel", "resources": [ResourceIds.MATTER]},
		{"key": "matter_decay", "label": "MatterDecayLabel", "resources": [ResourceIds.MATTER, ResourceIds.HEAT]},
	]

	for config in row_configs:
		var label := container.get_node_or_null(config["label"]) as Label
		if label == null:
			continue

		var original_index := label.get_index()
		container.remove_child(label)

		var row := HBoxContainer.new()
		row.name = str(config["label"]).trim_suffix("Label") + "Row"
		row.add_theme_constant_override("separation", 5)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(row)
		container.move_child(row, original_index)

		for resource_id in config["resources"]:
			var icon := ResourceIcon.new()
			icon.setup(resource_id, Vector2(14.0, 14.0))
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(icon)

		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		pressure_labels[config["key"]] = label

	var ash_row := HBoxContainer.new()
	ash_row.name = "AshContaminationRow"
	ash_row.add_theme_constant_override("separation", 5)
	ash_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var ash_icon := ResourceIcon.new()
	ash_icon.setup(ResourceIds.ASH, Vector2(14.0, 14.0))
	ash_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ash_row.add_child(ash_icon)

	var ash_label := Label.new()
	ash_label.name = "AshContaminationLabel"
	ash_label.add_theme_font_size_override("font_size", 10)
	ash_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ash_label.text = "Ash Contamination: 0"
	ash_row.add_child(ash_label)

	var separator := container.get_node_or_null("PressureSectionSeparator")
	if separator != null:
		container.add_child(ash_row)
		container.move_child(ash_row, separator.get_index())
	else:
		container.add_child(ash_row)

	pressure_labels["ash_contamination"] = ash_label


func update_pressure_stats() -> void:
	var overflow_rate = state.get_heat_leak_per_second()
	var matter_decay = state.get_matter_decay_per_second()
	var ash_contamination_multiplier := stats.get_raw_resource_modifier_multiplier(
		"ashen_contamination",
		ModifierTypes.PRODUCTION,
		""
	)

	var crystallized_flames = state.get_resource_amount(
		ResourceIds.CRYSTALLIZED_FLAME
	)
	var overflow_multiplier = pow(1.25, crystallized_flames)
	var heat_leak_threshold = state.realm_effects.heat_leak_threshold
	var matter_decay_threshold = state.realm_effects.matter_decay_threshold

	pressure_labels["heat_threshold"].text = (
		"Overflow Threshold: %s"
		% NumberFormatter.format(heat_leak_threshold)
	)
	pressure_labels["heat_rate"].text = (
		"Overflow Rate: %s /s"
		% NumberFormatter.format(overflow_rate)
	)
	pressure_labels["overflow_multiplier"].text = (
		"Overflow Multiplier: ×%s"
		% NumberFormatter.format(overflow_multiplier)
	)
	pressure_labels["overflow_this_realm"].text = (
		"Overflow This Realm: %s"
		% NumberFormatter.format(state.current_run_statistics.get_total_overflow())
	)
	pressure_labels["overflow_all_realms"].text = (
		"Overflow All Realms: %s"
		% NumberFormatter.format(state.resource_statistics.get_total_overflow())
	)
	pressure_labels["matter_threshold"].text = (
		"Decay Threshold: %s Matter"
		% NumberFormatter.format(matter_decay_threshold)
	)
	pressure_labels["matter_decay"].text = (
		"Decay: %s Matter/s → %s Heat/s"
		% [
			NumberFormatter.format(matter_decay),
			NumberFormatter.format(matter_decay)
		]
	)
	pressure_labels["ash_contamination"].text = (
		"Ash Contamination: ×%s"
		% NumberFormatter.format(ash_contamination_multiplier)
	)
