
class_name GeneratorUpgradeTree
extends Control


signal automation_settings_changed

var _last_styled_enabled: bool = false
var _has_styled_enabled: bool = false


func _ready() -> void:
	_setup_automation_button_style()


var state: GameState
var simulation: Simulation
var input_handler: InputHandler
var info_popup: UpgradeInfoPopup

var generator_id: String = ""
var layout: GeneratorUpgradeLayout

var connections: GeneratorUpgradeConnections

var upgrade_panel_scene = preload(
	"res://UI/upgrade_panel.tscn"
)


const UPGRADE_SIZE := Vector2(70, 70)
const HORIZONTAL_SPACING := 20.0
const VERTICAL_SPACING := 20.0
const COLUMNS := 4


func setup(
	game_state: GameState,
	game_simulation: Simulation,
	game_input_handler: InputHandler,
	game_generator_id: String,
	game_info_popup: UpgradeInfoPopup
	) -> void:

	state = game_state
	simulation = game_simulation
	input_handler = game_input_handler
	generator_id = game_generator_id
	info_popup = game_info_popup

	_rebuild()

func _process(_delta: float) -> void:
	_update_automation_button()


func _rebuild() -> void:

	_clear_tree()

	if state == null:
		return

	var generator = state.get_generator(
		generator_id
	)

	if generator == null:
		return

	$TitleLabel.text = (
		generator.definition.display_name
		+ " Upgrades"
	)

	layout = _get_layout()

	_create_connection_renderer()
	_create_upgrade_nodes()
	_update_automation_button()


func _create_upgrade_nodes() -> void:

	var max_y := 0.0

	for upgrade_value in state.upgrades.values():

		var upgrade: Upgrade = upgrade_value

		if upgrade.definition.generator_id != generator_id:
			continue

		if not state.upgrade_system.is_upgrade_visible(upgrade):
			continue

		var upgrade_id: String = upgrade.definition.id

		if not layout.positions.has(upgrade_id):
			continue

		var panel: UpgradePanel = upgrade_panel_scene.instantiate()

		panel.custom_minimum_size = UPGRADE_SIZE
		panel.size = UPGRADE_SIZE

		$TreeArea.add_child(panel)

		var position: Vector2 = layout.positions[upgrade_id]

		panel.position = position

		panel.exclusive_preference_changed.connect(
			_on_upgrade_panel_exclusive_preference_changed
		)

		panel.setup(
			state,
			simulation,
			input_handler,
			upgrade_id,
			info_popup
		)

		max_y = max(
			max_y,
			position.y + UPGRADE_SIZE.y
		)

	# Give the tree enough height for every node.
	$TreeArea.custom_minimum_size.y = max_y + 20.0
	custom_minimum_size.y = max_y + 82.0
	size.y = max_y + 82.0


func _update_automation_button() -> void:
	if state == null:
		return

	var manager: UpgradeAutomationManager = state.upgrade_automation_manager
	var unlocked: bool = manager.is_automation_unlocked(generator_id)
	$AutomationToggleButton.visible = unlocked

	if not unlocked:
		return

	var enabled: bool = manager.is_enabled(generator_id)
	$AutomationToggleButton.text = (
		"UPGRADE AUTO: ON"
		if enabled
		else "UPGRADE AUTO: OFF"
	)

	if not _has_styled_enabled or enabled != _last_styled_enabled:
		var background: Color = (
			Color(0.18, 0.36, 0.22, 1.0)
			if enabled
			else Color(0.25, 0.20, 0.20, 1.0)
		)
		var border: Color = (
			Color(0.55, 0.90, 0.52, 1.0)
			if enabled
			else Color(0.90, 0.52, 0.42, 1.0)
		)
		$AutomationToggleButton.add_theme_stylebox_override(
			"normal",
			_create_toggle_style(background, border)
		)
		$AutomationToggleButton.add_theme_stylebox_override(
			"hover",
			_create_toggle_style(background.lightened(0.12), border.lightened(0.12))
		)
		$AutomationToggleButton.add_theme_stylebox_override(
			"pressed",
			_create_toggle_style(background.darkened(0.10), border)
		)
		_last_styled_enabled = enabled
		_has_styled_enabled = true


func _setup_automation_button_style() -> void:
	$AutomationToggleButton.custom_minimum_size = Vector2(170, 28)
	$AutomationToggleButton.add_theme_font_size_override("font_size", 12)
	$AutomationToggleButton.focus_mode = Control.FOCUS_NONE


func _create_toggle_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _on_automation_toggle_button_pressed() -> void:
	if state == null:
		return

	var manager: UpgradeAutomationManager = state.upgrade_automation_manager
	if manager.set_enabled(generator_id, not manager.is_enabled(generator_id)):
		_update_automation_button()
		automation_settings_changed.emit()


func _on_upgrade_panel_exclusive_preference_changed() -> void:
	automation_settings_changed.emit()


func _clear_tree() -> void:

	for child in $TreeArea.get_children():
		child.queue_free()

func _get_layout() -> GeneratorUpgradeLayout:
	match generator_id:
		"atomic_friction":
			return AtomicFrictionUpgradeLayout.new()
		"molecular_agitation":
			return MolecularAgitationUpgradeLayout.new()
		"thermal_furnace":
			return ThermalFurnaceUpgradeLayout.new()
		"lava_mite_colony":
			return LavaMiteUpgradeLayout.new()
		"matter_furnace":
			return MatterFurnaceUpgradeLayout.new()
	return GeneratorUpgradeLayout.new()
func _create_connection_renderer() -> void:

	connections = GeneratorUpgradeConnections.new()

	connections.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	connections.mouse_filter = Control.MOUSE_FILTER_IGNORE

	$TreeArea.add_child(
		connections
	)

	$TreeArea.move_child(
		connections,
		0
	)

	connections.setup(
		layout,
		UPGRADE_SIZE
	)

