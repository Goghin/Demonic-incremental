class_name EternalFlameShopTree
extends Control


signal purchase_requested(upgrade_id: String)


var state: GameState
var layout: EternalFlameUpgradeLayout
var connection_renderer: EternalFlameUpgradeConnections
var upgrade_nodes: Dictionary = {}


const NODE_SIZE := EternalFlameUpgradeLayout.NODE_SIZE


func setup(game_state: GameState) -> void:
	state = game_state
	_build_tree()
	refresh()


func refresh() -> void:
	if state == null:
		return

	var manager: EternalFlameUpgradeManager = state.eternal_flame_upgrade_manager
	for upgrade_id in upgrade_nodes:
		var upgrade: EternalFlameUpgrade = manager.get_upgrade(upgrade_id)
		if upgrade == null:
			continue

		var node: Button = upgrade_nodes[upgrade_id]
		var level: int = manager.get_upgrade_level(upgrade_id, state.eternal_flame_state)
		var cost: int = manager.get_upgrade_cost(upgrade_id, state.eternal_flame_state)
		var can_buy: bool = manager.can_purchase(
			upgrade_id,
			state.eternal_flame_state,
			state.realm_configuration
		)
		var maxed: bool = level >= upgrade.max_level

		node.text = "%s\nLv. %d / %d\n%s" % [
			_format_node_title(upgrade.display_name),
			level,
			upgrade.max_level,
			"MAXED" if maxed else "%d Flame%s" % [cost, "" if cost == 1 else "s"]
		]
		node.tooltip_text = upgrade.description
		node.disabled = maxed or not can_buy
		_style_node(node, maxed, can_buy)


func _build_tree() -> void:
	for child in get_children():
		child.queue_free()
	upgrade_nodes.clear()

	if state == null:
		return

	layout = EternalFlameUpgradeLayout.new()
	custom_minimum_size = layout.get_map_size()
	size = custom_minimum_size

	connection_renderer = EternalFlameUpgradeConnections.new()
	connection_renderer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	connection_renderer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(connection_renderer)
	connection_renderer.setup(layout)

	var manager: EternalFlameUpgradeManager = state.eternal_flame_upgrade_manager
	for upgrade_id in layout.positions:
		var upgrade: EternalFlameUpgrade = manager.get_upgrade(upgrade_id)
		if upgrade == null:
			continue

		var node := Button.new()
		node.name = "%sNode" % upgrade_id
		node.position = layout.positions[upgrade_id]
		node.custom_minimum_size = NODE_SIZE
		node.size = NODE_SIZE
		node.add_theme_font_size_override("font_size", 13)
		node.focus_mode = Control.FOCUS_NONE
		node.pressed.connect(_on_upgrade_node_pressed.bind(upgrade_id))
		add_child(node)
		upgrade_nodes[upgrade_id] = node

	# Keep the lines behind all upgrade nodes.
	move_child(connection_renderer, 0)


func _on_upgrade_node_pressed(upgrade_id: String) -> void:
	purchase_requested.emit(upgrade_id)


func _style_node(node: Button, maxed: bool, can_buy: bool) -> void:
	var background := Color(0.15, 0.15, 0.18, 1.0)
	var border := Color(0.42, 0.42, 0.48, 1.0)

	if maxed:
		background = Color(0.20, 0.32, 0.16, 1.0)
		border = Color(0.68, 0.86, 0.38, 1.0)
	elif can_buy:
		background = Color(0.30, 0.21, 0.12, 1.0)
		border = Color(0.95, 0.66, 0.30, 1.0)

	node.add_theme_stylebox_override("normal", _create_node_style(background, border))
	node.add_theme_stylebox_override(
		"hover",
		_create_node_style(background.lightened(0.12), border.lightened(0.10))
	)
	node.add_theme_stylebox_override(
		"pressed",
		_create_node_style(background.darkened(0.10), border)
	)
	node.add_theme_stylebox_override("disabled", _create_node_style(background, border.darkened(0.10)))
	node.add_theme_color_override(
		"font_color",
		Color(1.0, 0.92, 0.78, 1.0) if maxed or can_buy else Color(0.70, 0.70, 0.73, 1.0)
	)
	node.add_theme_color_override("font_disabled_color", Color(0.70, 0.70, 0.73, 1.0))


func _create_node_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style

 
func _format_node_title(display_name: String) -> String:
	var words: PackedStringArray = display_name.split(" ")
	var lines: Array[String] = []
	var current_line: String = ""

	for word in words:
		if current_line.is_empty():
			current_line = word
		elif current_line.length() + word.length() + 1 <= 19:
			current_line += " " + word
		else:
			lines.append(current_line)
			current_line = word

	if not current_line.is_empty():
		lines.append(current_line)

	if lines.size() <= 2:
		return "\n".join(lines)

	return lines[0] + "\n" + lines[1]
