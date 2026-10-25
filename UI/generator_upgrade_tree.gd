
class_name GeneratorUpgradeTree
extends Control


signal automation_settings_changed
signal purchase_succeeded
signal relics_changed

var _last_styled_enabled: bool = false
var _has_styled_enabled: bool = false


func _ready() -> void:
	_setup_automation_button_style()


var state: GameState
var simulation: Simulation
var input_handler: InputHandler
var info_popup: UpgradeInfoPopup

var generator_id: String = ""
var stats: GameStats
var stats_entry: GeneratorStatsEntry
var stats_view_active: bool = false
var active_view: String = "upgrades"
var relics_panel: ReliquaryPanel
var layout: GeneratorUpgradeLayout

var connections: GeneratorUpgradeConnections

var upgrade_panel_scene = preload(
	"res://UI/upgrade_panel.tscn"
)


const UPGRADE_SIZE := Vector2(44, 44)
const HORIZONTAL_SPACING := 10.0
const VERTICAL_SPACING := 10.0
const COLUMNS := 4


func setup(
	game_state: GameState,
	game_simulation: Simulation,
	game_input_handler: InputHandler,
	game_generator_id: String,
	game_info_popup: UpgradeInfoPopup
	) -> void:

	state = game_state
	stats = GameStats.new(game_state)
	simulation = game_simulation
	input_handler = game_input_handler
	generator_id = game_generator_id
	info_popup = game_info_popup

	_rebuild()

func _process(_delta: float) -> void:
	_update_automation_button()


func _rebuild() -> void:

	_clear_tree()
	_clear_stats_view()
	stats_view_active = false

	if state == null:
		return

	var generator = state.get_generator(
		generator_id
	)

	if generator == null:
		return

	$Header/TitleLabel.text = (
		generator.definition.display_name
		+ " Upgrades"
	)

	layout = _get_layout()

	_create_connection_renderer()
	_create_upgrade_nodes()
	_create_stats_view(generator_id)
	_ensure_relics_panel()
	_set_active_view("upgrades")
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

		$TreeScroll/TreeArea.add_child(panel)

		var node_position: Vector2 = layout.positions[upgrade_id]

		panel.position = node_position

		panel.exclusive_preference_changed.connect(
			_on_upgrade_panel_exclusive_preference_changed
		)
		panel.purchase_succeeded.connect(
			_on_upgrade_purchase_succeeded
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
			node_position.y + UPGRADE_SIZE.y
		)

	# The inner scroll area owns the tree height; the header stays fixed.
	$TreeScroll/TreeArea.custom_minimum_size.y = max_y + 20.0


func _create_stats_view(target_generator_id: String) -> void:
	if state == null or stats == null:
		return
	stats_entry = preload("res://UI/GeneratorStatsEntry.tscn").instantiate() as GeneratorStatsEntry
	stats_entry.name = target_generator_id
	stats_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$StatsScroll/StatsContent.add_child(stats_entry)
	stats_entry.setup(state, stats, target_generator_id)
	stats_entry.expanded = true


func _clear_stats_view() -> void:
	for child in $StatsScroll/StatsContent.get_children():
		child.queue_free()
	stats_entry = null


func _ensure_relics_panel() -> void:
	if state == null:
		return
	if relics_panel == null:
		relics_panel = ReliquaryPanel.new()
		relics_panel.name = "FocusedGeneratorRelics"
		relics_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		relics_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# RelicsView is a Control, not a Container. Explicitly fill its
		# rectangle so the inventory grid and equipment slots receive space.
		relics_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		$RelicsView.add_child(relics_panel)
		relics_panel.relics_changed.connect(_on_relics_changed)
		relics_panel.setup(
			state,
			ReliquaryPanel.DISPLAY_FOCUSED_GENERATOR_RELICS,
			generator_id,
			input_handler
		)
	else:
		relics_panel.set_display_mode(
			ReliquaryPanel.DISPLAY_FOCUSED_GENERATOR_RELICS,
			generator_id
		)


func _set_active_view(view_name: String) -> void:
	active_view = view_name if view_name in ["upgrades", "stats", "relics"] else "upgrades"
	stats_view_active = active_view == "stats"
	$TreeScroll.visible = active_view == "upgrades"
	$StatsScroll.visible = active_view == "stats"
	$RelicsView.visible = active_view == "relics"
	$Header/UpgradesViewButton.button_pressed = active_view == "upgrades"
	$Header/StatsViewButton.button_pressed = active_view == "stats"
	$Header/RelicsViewButton.button_pressed = active_view == "relics"
	var generator = state.get_generator(generator_id) if state != null else null
	var generator_name: String = generator.definition.display_name if generator != null else "Generator"
	var view_label := "Upgrades" if active_view == "upgrades" else ("Stats" if active_view == "stats" else "Relics")
	$Header/TitleLabel.text = generator_name + " " + view_label
	if active_view == "relics" and relics_panel != null:
		relics_panel.refresh()


func _set_view_mode(show_stats: bool) -> void:
	_set_active_view("stats" if show_stats else "upgrades")


func _on_upgrades_view_button_pressed() -> void:
	_set_active_view("upgrades")


func _on_stats_view_button_pressed() -> void:
	_set_active_view("stats")


func _on_relics_view_button_pressed() -> void:
	_set_active_view("relics")


func _on_relics_changed() -> void:
	relics_changed.emit()


func show_stats_view() -> void:
	_set_active_view("stats")


func _update_automation_button() -> void:
	if state == null:
		return

	var manager: UpgradeAutomationManager = state.upgrade_automation_manager
	var unlocked: bool = manager.is_automation_unlocked(generator_id)
	$Header/AutomationToggleButton.visible = unlocked

	if not unlocked:
		return

	var enabled: bool = manager.is_enabled(generator_id)
	$Header/AutomationToggleButton.text = (
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
		$Header/AutomationToggleButton.add_theme_stylebox_override(
			"normal",
			_create_toggle_style(background, border)
		)
		$Header/AutomationToggleButton.add_theme_stylebox_override(
			"hover",
			_create_toggle_style(background.lightened(0.12), border.lightened(0.12))
		)
		$Header/AutomationToggleButton.add_theme_stylebox_override(
			"pressed",
			_create_toggle_style(background.darkened(0.10), border)
		)
		_last_styled_enabled = enabled
		_has_styled_enabled = true


func _setup_automation_button_style() -> void:
	$Header/AutomationToggleButton.custom_minimum_size = Vector2(160, 24)
	$Header/AutomationToggleButton.add_theme_font_size_override("font_size", 11)
	$Header/AutomationToggleButton.focus_mode = Control.FOCUS_NONE


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


func _on_upgrade_purchase_succeeded() -> void:
	purchase_succeeded.emit()


func _clear_tree() -> void:

	for child in $TreeScroll/TreeArea.get_children():
		child.queue_free()

func _get_layout() -> GeneratorUpgradeLayout:
	match generator_id:
		"atomic_friction":
			return AtomicFrictionUpgradeLayout.new()
		"molecular_agitation":
			return MolecularAgitationUpgradeLayout.new()
		"thermal_furnace":
			return ThermalFurnaceUpgradeLayout.new()
		"thermal_compressor":
			return ThermalCompressorUpgradeLayout.new()
		"infernal_forge":
			return InfernalForgeUpgradeLayout.new()
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

	$TreeScroll/TreeArea.add_child(
		connections
	)

	$TreeScroll/TreeArea.move_child(
		connections,
		0
	)

	connections.setup(
		layout,
		UPGRADE_SIZE
	)
