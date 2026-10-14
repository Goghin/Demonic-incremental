class_name ResourcePanel
extends Control


const RESOURCE_CARD_MIN_SIZE := Vector2(170.0, 58.0)
const ICON_PLACEHOLDER_SIZE := Vector2(34.0, 34.0)

var state: GameState
var stats: GameStats
var resource_cards: Dictionary = {}
var info_popup: ResourceInfoPopup
var hovered_resource_id: String = ""
var current_run_index: int = -1


func _ready() -> void:
	info_popup = ResourceInfoPopup.new()
	info_popup.name = "ResourceInfoPopup"
	add_child(info_popup)
	info_popup.hide()


func setup(game_state: GameState) -> void:
	state = game_state
	stats = GameStats.new(state)
	current_run_index = state.gameplay_realm_run_index
	_refresh_discovered_resources()


func _process(_delta: float) -> void:
	if state == null:
		return

	# A resource is only shown after it has existed in this run. Clear the
	# displayed set on a new run, then let resources reappear as they are made.
	if current_run_index != state.gameplay_realm_run_index:
		current_run_index = state.gameplay_realm_run_index
		_clear_resource_cards()

	_refresh_discovered_resources()
	_update_resource_amounts()

	if info_popup != null and info_popup.visible:
		info_popup.refresh()


func _refresh_discovered_resources() -> void:
	if state == null:
		return

	for resource_id in state.get_resources():
		if resource_cards.has(resource_id):
			continue

		if _has_discovered_resource(resource_id):
			_create_resource_card(resource_id)


func _has_discovered_resource(resource_id: String) -> bool:
	if state.get_resource_amount(resource_id) > 0.0:
		return true

	# Statistics preserve discovery even if the resource is later fully spent.
	# This also restores discovery correctly when loading a save with zero stock.
	var run_stats: ResourceStatistics = state.current_run_statistics
	return (
		run_stats.get_highest_amount(resource_id) > 0.0
		or run_stats.get_total_produced(resource_id) > 0.0
		or run_stats.get_total_consumed(resource_id) > 0.0
		or run_stats.get_total_lost(resource_id) > 0.0
	)


func _create_resource_card(resource_id: String) -> void:
	var card := PanelContainer.new()
	card.name = "ResourceCard_%s" % resource_id
	card.custom_minimum_size = RESOURCE_CARD_MIN_SIZE
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.add_theme_stylebox_override("panel", _make_card_style())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	card.add_child(row)

	# Empty icon frame: reserved for the resource's eventual icon artwork.
	var icon_frame := PanelContainer.new()
	icon_frame.name = "IconPlaceholder"
	icon_frame.custom_minimum_size = ICON_PLACEHOLDER_SIZE
	icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_frame.add_theme_stylebox_override("panel", _make_icon_placeholder_style())
	row.add_child(icon_frame)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_column.add_theme_constant_override("separation", 2)
	row.add_child(text_column)

	var name_label := Label.new()
	name_label.name = "ResourceName"
	name_label.text = state.get_resource_display_name(resource_id)
	name_label.add_theme_font_size_override("font_size", 13)
	text_column.add_child(name_label)

	var amount_label := Label.new()
	amount_label.name = "ResourceAmount"
	amount_label.add_theme_font_size_override("font_size", 16)
	amount_label.text = NumberFormatter.format(
		state.get_resource_amount(resource_id)
	)
	text_column.add_child(amount_label)

	$ResourceContainer.add_child(card)
	card.mouse_entered.connect(
		_on_resource_card_mouse_entered.bind(resource_id)
	)
	card.mouse_exited.connect(
		_on_resource_card_mouse_exited.bind(resource_id)
	)
	resource_cards[resource_id] = {
		"card": card,
		"amount_label": amount_label
	}


func _update_resource_amounts() -> void:
	for resource_id in resource_cards:
		var amount_label: Label = resource_cards[resource_id]["amount_label"]
		amount_label.text = NumberFormatter.format(
			state.get_resource_amount(resource_id)
		)


func _clear_resource_cards() -> void:
	for child in $ResourceContainer.get_children():
		child.queue_free()

	resource_cards.clear()


func _make_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.045, 0.055, 0.94)
	style.border_color = Color(0.32, 0.22, 0.20, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	return style


func _make_icon_placeholder_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.085, 0.09, 1.0)
	style.border_color = Color(0.42, 0.31, 0.29, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(0)
	return style



func _on_resource_card_mouse_entered(resource_id: String) -> void:
	if state == null or stats == null or info_popup == null:
		return

	hovered_resource_id = resource_id
	info_popup.setup(state, stats, resource_id)
	info_popup.show()

	# Wait for the popup and card layouts to settle before positioning it.
	await get_tree().process_frame

	if hovered_resource_id != resource_id:
		return

	var card_data: Dictionary = resource_cards.get(resource_id, {})
	var card: Control = card_data.get("card")
	if card == null or not is_instance_valid(card):
		return

	var viewport_rect := get_viewport().get_visible_rect()
	var card_rect := card.get_global_rect()
	var popup_size := info_popup.size
	var popup_global_position := card_rect.position + Vector2(0.0, card_rect.size.y + 6.0)

	if popup_global_position.y + popup_size.y > viewport_rect.end.y:
		popup_global_position.y = card_rect.position.y - popup_size.y - 6.0

	popup_global_position.x = clampf(
		popup_global_position.x,
		viewport_rect.position.x + 6.0,
		maxf(viewport_rect.position.x + 6.0, viewport_rect.end.x - popup_size.x - 6.0)
	)

	info_popup.global_position = popup_global_position


func _on_resource_card_mouse_exited(resource_id: String) -> void:
	if hovered_resource_id != resource_id:
		return

	hovered_resource_id = ""
	if info_popup != null:
		info_popup.hide()
