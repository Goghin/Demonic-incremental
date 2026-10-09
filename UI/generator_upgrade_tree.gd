
class_name GeneratorUpgradeTree
extends Control


signal automation_settings_changed


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
	_create_automation_controls()


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


func _create_automation_controls() -> void:
	var controls: HFlowContainer = $AutomationControls

	for child in controls.get_children():
		child.queue_free()

	if state == null or not state.upgrade_automation_manager.is_automation_unlocked(generator_id):
		var locked_label := Label.new()
		locked_label.text = "Upgrade automation: locked in Eternal Flame Shop"
		controls.add_child(locked_label)
		return

	var manager: UpgradeAutomationManager = state.upgrade_automation_manager

	var automation_toggle := CheckBox.new()
	automation_toggle.text = "AUTO BUY"
	automation_toggle.button_pressed = manager.is_enabled(generator_id)
	automation_toggle.toggled.connect(
		func(enabled: bool):
			if manager.set_enabled(generator_id, enabled):
				automation_settings_changed.emit()
	)
	controls.add_child(automation_toggle)

	for upgrade_value in state.upgrades.values():
		var upgrade: Upgrade = upgrade_value

		if upgrade.definition.generator_id != generator_id:
			continue

		if upgrade.definition.exclusivity_group == "":
			continue

		if not state.upgrade_system.is_upgrade_visible(upgrade):
			continue

		var preference_toggle := CheckBox.new()
		preference_toggle.text = upgrade.definition.display_name
		preference_toggle.tooltip_text = "Allow the autobuyer to choose this exclusive upgrade."
		preference_toggle.button_pressed = manager.is_exclusive_preference_selected(
			upgrade.definition.id
		)
		preference_toggle.toggled.connect(
			_on_exclusive_preference_toggled.bind(
				upgrade.definition.id
			)
		)
		controls.add_child(preference_toggle)


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


func _on_exclusive_preference_toggled(
	selected: bool,
	upgrade_id: String
) -> void:
	state.upgrade_automation_manager.set_exclusive_preference(
		upgrade_id,
		selected
	)
	_create_automation_controls()
	automation_settings_changed.emit()
