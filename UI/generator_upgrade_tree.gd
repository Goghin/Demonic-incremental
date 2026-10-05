
class_name GeneratorUpgradeTree
extends Control


var state: GameState
var simulation: Simulation
var input_handler: InputHandler
var info_popup: UpgradeInfoPopup

var generator_id: String = ""

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

	_create_upgrade_nodes()


func _create_upgrade_nodes() -> void:

	var upgrades: Array = []

	for upgrade in state.upgrades.values():

		if upgrade.definition.generator_id != generator_id:
			continue

		if not state.upgrade_system.is_upgrade_visible(
			upgrade
		):
			continue

		upgrades.append(
			upgrade
		)

	var column := 0
	var row := 0

	for upgrade in upgrades:

		var panel = upgrade_panel_scene.instantiate()

		panel.custom_minimum_size = UPGRADE_SIZE
		panel.size = UPGRADE_SIZE

		$TreeArea.add_child(
			panel
		)

		panel.position = Vector2(
			column * (
				UPGRADE_SIZE.x
				+ HORIZONTAL_SPACING
			),
			row * (
				UPGRADE_SIZE.y
				+ VERTICAL_SPACING
			)
		)

		panel.setup(
			state,
			simulation,
			input_handler,
			upgrade.definition.id,
			info_popup
		)

		column += 1

		if column >= COLUMNS:
			column = 0
			row += 1


func _clear_tree() -> void:

	for child in $TreeArea.get_children():
		child.queue_free()
