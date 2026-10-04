
class_name StatsPanel
extends Control


const RESOURCE_NAME_WIDTH := 110
const RESOURCE_AMOUNT_WIDTH := 100
const RESOURCE_PRODUCTION_WIDTH := 115
const RESOURCE_CONSUMPTION_WIDTH := 115
const RESOURCE_NET_WIDTH := 115
const RESOURCE_STATISTICS_NAME_WIDTH := 110
const RESOURCE_STATISTICS_VALUE_WIDTH := 100

var state: GameState
var stats: GameStats
var time_manager: TimeManager

var resource_stat_rows: Dictionary = {}
var resource_statistics_rows: Dictionary = {}

func setup(
	game_state: GameState,
	game_time_manager: TimeManager
	) -> void:
	state = game_state
	stats = GameStats.new(state)
	time_manager = game_time_manager
	
	_setup_resource_stats()
	_setup_resource_statistics()

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
		
		var name_label = _create_column_label(
			resource.definition.display_name,
			RESOURCE_NAME_WIDTH,
			HORIZONTAL_ALIGNMENT_LEFT,
			11
		)
		
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
		
		row.add_child(name_label)
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
	
	for resource in state.get_resources().values():
		var resource_id = resource.definition.id
		
		# Resource name
		var name_label = _create_column_label(
			resource.definition.display_name,
			RESOURCE_STATISTICS_NAME_WIDTH,
			HORIZONTAL_ALIGNMENT_LEFT,
			11
		)
		
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
		stats_container.add_child(
			all_realms_label
		)
		stats_container.add_child(
			all_realms_values
		)
		
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 90)
		
		row.add_child(name_label)
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
			"Produced: %s    Consumed: %s    Lost: %s    Highest: %s"
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
			"Produced: %s    Consumed: %s    Lost: %s    Highest: %s"
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

		# Overflow is specifically associated with Heat.
		if resource_id == ResourceIds.HEAT:
			this_realm_text += (
				"    Overflow: %s"
				% NumberFormatter.format(
					current_run_statistics.get_total_overflow()
				)
			)

			all_realms_text += (
				"    Overflow: %s"
				% NumberFormatter.format(
					lifetime_statistics.get_total_overflow()
				)
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
	var total_seconds = int(seconds)
	
	var days = int(total_seconds / 86400)
	var hours = int((total_seconds % 86400) / 3600)
	var minutes = int((total_seconds % 3600) / 60)
	var remaining_seconds = int(total_seconds % 60)
	
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

func update_pressure_stats() -> void:
	var overflow_rate = state.get_heat_leak_per_second()
	var matter_decay = state.get_matter_decay_per_second()

	var crystallized_flames = state.get_resource_amount(
		ResourceIds.CRYSTALIZED_FLAME
	)

	var overflow_multiplier = pow(
		1.25,
		crystallized_flames
	)

	var heat_leak_threshold = (
		state.realm_effects.heat_leak_threshold
	)

	var matter_decay_threshold = (
		state.realm_effects.matter_decay_threshold
	)

	$ScrollContainer/VBoxContainer/PressureContainer/HeatLeakageThresholdLabel.text = (
		"Overflow Threshold: %s"
		% NumberFormatter.format(heat_leak_threshold)
	)

	$ScrollContainer/VBoxContainer/PressureContainer/HeatLeakageLabel.text = (
		"Overflow Rate: %s /s"
		% NumberFormatter.format(overflow_rate)
	)

	$ScrollContainer/VBoxContainer/PressureContainer/OverflowMultiplierLabel.text = (
		"Overflow Multiplier: ×%s"
		% NumberFormatter.format(overflow_multiplier)
	)

	$ScrollContainer/VBoxContainer/PressureContainer/MatterDecayThresholdLabel.text = (
		"Decay Threshold: %s Matter"
		% NumberFormatter.format(matter_decay_threshold)
	)

	$ScrollContainer/VBoxContainer/PressureContainer/MatterDecayLabel.text = (
		"Decay: %s Matter/s → %s Heat/s"
		% [
			NumberFormatter.format(matter_decay),
			NumberFormatter.format(matter_decay)
		]
	)
