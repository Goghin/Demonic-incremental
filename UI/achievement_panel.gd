class_name AchievementPanel
extends Control


var state: GameState
var achievement_manager: AchievementManager
var achievement_rows: Dictionary = {}


@onready var summary_label: Label = $ScrollContainer/Content/SummaryLabel
@onready var achievement_list: VBoxContainer = $ScrollContainer/Content/AchievementList


func setup(
	game_state: GameState,
	manager: AchievementManager
	) -> void:

	state = game_state
	achievement_manager = manager
	_build_achievement_rows()
	refresh()


func refresh() -> void:
	if state == null or achievement_manager == null:
		return

	summary_label.text = "Unlocked: %d / %d" % [
		achievement_manager.get_unlocked_count(),
		achievement_manager.get_total_count()
	]

	for definition in AchievementRegistry.get_definitions():
		var achievement_id: String = str(
			definition.get("id", "")
		)
		if not achievement_rows.has(achievement_id):
			continue

		var row: Dictionary = achievement_rows[achievement_id]
		var progress: float = achievement_manager.get_progress(
			achievement_id,
			state
		)
		var target: float = achievement_manager.get_target(
			achievement_id
		)
		var is_unlocked: bool = achievement_manager.is_unlocked(
			achievement_id
		)

		var progress_ratio: float = 0.0
		if target > 0.0:
			progress_ratio = clampf(
				progress / target,
				0.0,
				1.0
			)

		row["status"].text = "UNLOCKED" if is_unlocked else "LOCKED"
		row["status"].modulate = (
			Color(0.72, 0.92, 0.66, 1.0)
			if is_unlocked
			else Color(0.68, 0.68, 0.68, 1.0)
		)
		row["progress_bar"].value = progress_ratio * 100.0
		row["progress_label"].text = "%s / %s" % [
			_format_amount(minf(progress, target)),
			_format_amount(target)
		]


func _build_achievement_rows() -> void:
	for child in achievement_list.get_children():
		child.queue_free()

	achievement_rows.clear()

	for definition in AchievementRegistry.get_definitions():
		var achievement_id: String = str(
			definition.get("id", "")
		)

		var card := PanelContainer.new()
		card.name = achievement_id
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 88)
		achievement_list.add_child(card)

		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 3)
		card.add_child(content)

		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation", 8)
		content.add_child(heading)

		var title := Label.new()
		title.text = str(definition.get("title", achievement_id))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_font_size_override("font_size", 12)
		heading.add_child(title)

		var status := Label.new()
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status.add_theme_font_size_override("font_size", 10)
		heading.add_child(status)

		var description := Label.new()
		description.text = str(definition.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 10)
		content.add_child(description)

		var progress_bar := ProgressBar.new()
		progress_bar.min_value = 0.0
		progress_bar.max_value = 100.0
		progress_bar.show_percentage = false
		progress_bar.custom_minimum_size = Vector2(0, 8)
		content.add_child(progress_bar)

		var progress_label := Label.new()
		progress_label.add_theme_font_size_override("font_size", 9)
		progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		content.add_child(progress_label)

		achievement_rows[achievement_id] = {
			"status": status,
			"progress_bar": progress_bar,
			"progress_label": progress_label
		}


func _format_amount(amount: float) -> String:
	if amount >= 1000000000.0:
		return "%.2fB" % (amount / 1000000000.0)
	if amount >= 1000000.0:
		return "%.2fM" % (amount / 1000000.0)
	if amount >= 1000.0:
		return "%.1fK" % (amount / 1000.0)
	return "%.0f" % amount
