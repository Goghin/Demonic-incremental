class_name AssistantPopup
extends Control

signal tutorial_dismissed(tutorial_id: String)
signal tutorial_replay_requested(tutorial_id: String)

var _active_tutorial_id: String = ""
var _title_label: Label
var _message_label: Label
var _dialog_panel: PanelContainer
var _archive_panel: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func show_tutorial(tutorial_id: String, title: String, message: String) -> void:
	_active_tutorial_id = tutorial_id
	_title_label.text = title
	_message_label.text = message
	if _archive_panel != null:
		_archive_panel.hide()
	_dialog_panel.show()
	visible = true


func show_archive(entries: Array[Dictionary]) -> void:
	_active_tutorial_id = ""
	if _archive_panel == null:
		_build_archive_ui()
	var list := _archive_panel.get_node("ArchiveContent/ArchiveScroll/ArchiveEntries") as VBoxContainer
	for child in list.get_children():
		child.queue_free()
	await get_tree().process_frame
	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No field notes recorded yet. Lessons appear here after you have seen them."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(empty_label)
	else:
		for entry in entries:
			var entry_button := Button.new()
			entry_button.text = str(entry.get("title", "INFERNAL INTERN"))
			entry_button.custom_minimum_size = Vector2(0, 38)
			entry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			entry_button.pressed.connect(
				_on_archive_entry_pressed.bind(str(entry.get("id", "")))
			)
			list.add_child(entry_button)
	_dialog_panel.hide()
	_archive_panel.show()
	visible = true


func _build_archive_ui() -> void:
	_archive_panel = PanelContainer.new()
	_archive_panel.name = "TutorialArchive"
	_archive_panel.anchor_left = 0.5
	_archive_panel.anchor_top = 0.5
	_archive_panel.anchor_right = 0.5
	_archive_panel.anchor_bottom = 0.5
	_archive_panel.offset_left = -250
	_archive_panel.offset_top = -215
	_archive_panel.offset_right = 250
	_archive_panel.offset_bottom = 215
	_archive_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(_archive_panel)

	var content := VBoxContainer.new()
	content.name = "ArchiveContent"
	content.add_theme_constant_override("separation", 10)
	_archive_panel.add_child(content)

	var title := Label.new()
	title.text = "INFERNAL INTERN'S FIELD NOTES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", Color(1.0, 0.68, 0.35))
	title.add_theme_font_size_override("font_size", 16)
	content.add_child(title)

	var description := Label.new()
	description.text = "Revisit any lesson you have already received."
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_color_override("font_color", Color(0.88, 0.82, 0.78))
	content.add_child(description)

	var scroll := ScrollContainer.new()
	scroll.name = "ArchiveScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	var entries := VBoxContainer.new()
	entries.name = "ArchiveEntries"
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 6)
	scroll.add_child(entries)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(footer)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(110, 36)
	close_button.pressed.connect(_on_archive_close_pressed)
	footer.add_child(close_button)
	_archive_panel.hide()


func _on_archive_entry_pressed(tutorial_id: String) -> void:
	if tutorial_id == "":
		return
	_archive_panel.hide()
	tutorial_replay_requested.emit(tutorial_id)


func _on_archive_close_pressed() -> void:
	_archive_panel.hide()
	visible = false


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.01, 0.02, 0.68)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_dialog_panel = PanelContainer.new()
	_dialog_panel.name = "AssistantDialog"
	_dialog_panel.anchor_left = 0.5
	_dialog_panel.anchor_top = 0.5
	_dialog_panel.anchor_right = 0.5
	_dialog_panel.anchor_bottom = 0.5
	_dialog_panel.offset_left = -230
	_dialog_panel.offset_top = -145
	_dialog_panel.offset_right = 230
	_dialog_panel.offset_bottom = 145
	_dialog_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(_dialog_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_dialog_panel.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)

	var imp_badge := PanelContainer.new()
	imp_badge.custom_minimum_size = Vector2(64, 64)
	imp_badge.add_theme_stylebox_override("panel", _make_badge_style())
	header.add_child(imp_badge)

	var imp_label := Label.new()
	imp_label.text = "IMP"
	imp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	imp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	imp_label.add_theme_color_override("font_color", Color(1.0, 0.56, 0.23))
	imp_label.add_theme_font_size_override("font_size", 18)
	imp_badge.add_child(imp_label)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.text = "A WORD FROM YOUR INFERNAL INTERN"
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.68, 0.35))
	_title_label.add_theme_font_size_override("font_size", 16)
	header.add_child(_title_label)

	_message_label = Label.new()
	_message_label.custom_minimum_size = Vector2(400, 110)
	_message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.add_theme_color_override("font_color", Color(0.88, 0.82, 0.78))
	content.add_child(_message_label)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(footer)

	var continue_button := Button.new()
	continue_button.text = "GOT IT"
	continue_button.custom_minimum_size = Vector2(110, 36)
	continue_button.pressed.connect(_on_continue_pressed)
	footer.add_child(continue_button)


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.04, 0.055, 0.99)
	style.border_color = Color(0.72, 0.31, 0.16, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style


func _make_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.075, 0.055, 1.0)
	style.border_color = Color(0.48, 0.22, 0.14, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style


func _on_continue_pressed() -> void:
	var dismissed_id := _active_tutorial_id
	_active_tutorial_id = ""
	visible = false
	tutorial_dismissed.emit(dismissed_id)
