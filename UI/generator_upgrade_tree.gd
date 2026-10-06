
class_name GeneratorUpgradeTree
extends Control


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
	custom_minimum_size.y = max_y + 20.0
	size.y = max_y + 20.0


func _clear_tree() -> void:

	for child in $TreeArea.get_children():
		child.queue_free()

func _get_layout() -> GeneratorUpgradeLayout:

	match generator_id:
		"atomic_friction":
			return AtomicFrictionUpgradeLayout.new()

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
