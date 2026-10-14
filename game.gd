
extends Control


var is_loading: bool = true
var visual_effects_enabled: bool = true
var ui_sounds_enabled: bool = true
var master_volume_percent: float = 70.0
var ui_click_player: AudioStreamPlayer
var ui_purchase_player: AudioStreamPlayer
var ui_unlock_player: AudioStreamPlayer

var ambient_enabled: bool = true
var ambient_players: Array[AudioStreamPlayer] = []
var ambient_active_player_index: int = 0
var ambient_track_order: Array[int] = []
var ambient_track_order_index: int = 0
var ambient_current_track_index: int = -1
var ambient_next_track_index: int = -1
var ambient_crossfade_active: bool = false
var ambient_crossfade_elapsed: float = 0.0

const AMBIENT_CROSSFADE_DURATION: float = 8.0
const AMBIENT_TRACKS = [
	preload("res://Assets/ogg/01 Ashes From The Previous World.ogg"),
	preload("res://Assets/ogg/02 Now Is All I've Got.ogg"),
	preload("res://Assets/ogg/03 Memento Mori.ogg"),
	preload("res://Assets/ogg/04 Dust Over The Dead Horizon.ogg"),
	preload("res://Assets/ogg/05 Chamber Of Rust.ogg"),
	preload("res://Assets/ogg/06 Rituals Of The Void.ogg")
]

var state: GameState
var simulation: Simulation
var time_manager: TimeManager
var input_handler: InputHandler
var save_manager: SaveManager
var pending_offline_achievement_ids: Array[String] = []

var upgrade_group_containers: Dictionary = {}
var upgrade_flows: Dictionary = {}
var upgrade_panels: Dictionary = {}

var selected_upgrade_generator_id: String = ""
var selected_generator_id: String = ""
var generator_list_mode: bool = false

var effects_flow: HFlowContainer
var prestige_animation: PrestigeAnimation

var generator_upgrade_tree: GeneratorUpgradeTree

var generator_panel_scene = preload(
	"res://UI/generator_panel.tscn"
)

var upgrade_panel_scene = preload(
	"res://UI/upgrade_panel.tscn"
)
var generator_upgrade_tree_scene = preload(
	"res://UI/generator_upgrade_tree.tscn"
)

const realm_view_scene: PackedScene = preload("res://RealmView/RealmView.tscn")

var realm_view: RealmView

@onready var loading_screen: Control = $LoadingScreen
@onready var offline_results_panel: Control = $OfflineResultsPanel

func _ready() -> void:
	$OfflineResultsPanel.results_closed.connect(
		_on_offline_results_closed
	)
	_load_visual_settings()
	$OptionsPanel/OptionsContent/VisualEffectsCheckBox.set_pressed_no_signal(visual_effects_enabled)
	$OptionsPanel/OptionsContent/UISoundsCheckBox.set_pressed_no_signal(ui_sounds_enabled)
	$OptionsPanel/OptionsContent/AmbientAudioCheckBox.set_pressed_no_signal(ambient_enabled)
	$OptionsPanel/OptionsContent/MasterVolumeSlider.set_value_no_signal(master_volume_percent)
	_update_master_volume_label()
	_apply_master_volume()
	_setup_ui_audio()
	_setup_ambient_audio()
	loading_screen.set_status(
		"Awakening the realm..."
	)
	loading_screen.set_progress(
		0.0
	)

	await get_tree().process_frame
	
	state = GameState.new()
	prestige_animation = $PrestigeAnimation
	
	_create_realm_view()
	realm_view.set_visual_effects_enabled(visual_effects_enabled)
	
	
		
	prestige_animation.setup(realm_view)

	$PrestigePanel.prestige_requested.connect(
		_on_prestige_requested
	)


	prestige_animation.destruction_complete.connect(
		_on_prestige_destruction_complete
	)
	loading_screen.set_status(
		"Initializing the simulation..."
	)
	loading_screen.set_progress(
		0.15
	)

	await get_tree().process_frame

	simulation = Simulation.new(
		state
	)
	simulation.crystallization_completed.connect(
		realm_view.play_crystallization_event
		)
	loading_screen.set_status(
		"Preparing the flow of time..."
	)
	loading_screen.set_progress(
		0.25
	)

	await get_tree().process_frame

	time_manager = TimeManager.new(
		simulation
	)
	time_manager.offline_simulation_progress.connect(
		_on_offline_simulation_progress
	)
	loading_screen.set_status(
		"Preparing controls..."
	)
	loading_screen.set_progress(
		0.35
	)

	await get_tree().process_frame

	save_manager = SaveManager.new()
	input_handler = InputHandler.new(
		simulation
	)

	loading_screen.set_status(
		"Restoring your dominion..."
	)
	loading_screen.set_progress(
		0.45
	)

	await get_tree().process_frame

	var loaded = save_manager.load_game(
		state,
		time_manager
	)
	state.achievement_manager.update(state)
	realm_view.rebuild_realm(
		state.realm_layout
	)

	if loaded:
		simulation.rebuild_upgrade_effects()

		loading_screen.set_status(
			"Simulating time lost to the void..."
		)
		loading_screen.set_progress(
			0.55
		)

		await get_tree().process_frame

		state.achievement_manager.achievement_unlocked.connect(
			_on_offline_achievement_unlocked
		)
		var offline_seconds = await time_manager.process_offline_time()
		state.achievement_manager.update(state)
		state.achievement_manager.achievement_unlocked.disconnect(
			_on_offline_achievement_unlocked
		)

		print(
			"Offline time simulated: ",
			offline_seconds,
			" seconds"
		)

		if offline_seconds > 0.0:
			save_manager.save_game(state, time_manager)

			var results_text = _build_offline_results(
				offline_seconds
			)

			$OfflineResultsPanel.show_results(
				offline_seconds,
				results_text
			)

	loading_screen.set_status(
		"Preparing resources..."
	)
	loading_screen.set_progress(
		0.65
	)

	await get_tree().process_frame

	$ResourcePanel.setup(
		state
	)

	$StatsPanel.setup(
		state,
		time_manager
	)

	$AchievementPanel.setup(
		state,
		state.achievement_manager
	)
	state.achievement_manager.achievement_unlocked.connect(
		_on_achievement_unlocked
	)

	$PrestigePanel.setup(
		state,
		save_manager,
		time_manager
	)
	$PrestigePanel.technology_unlocked.connect(
		_on_technology_unlocked
	)
	$PrestigePanel.run_reset.connect(
		_on_run_reset
	)
	print(
		"Timestamp: ",
		time_manager.last_real_timestamp
	)

	print(
		"Offline seconds: ",
		time_manager.get_offline_seconds()
	)

	loading_screen.set_status(
		"Awakening generators..."
	)
	loading_screen.set_progress(
		0.75
	)

	await get_tree().process_frame

	_create_initial_generator_panels()
	_initialize_generator_selection()

	loading_screen.set_status(
		"Rebuilding upgrades..."
	)
	loading_screen.set_progress(
		0.85
	)

	await get_tree().process_frame

	_create_initial_upgrade_ui()
	_create_generator_upgrade_tree()
	
	# Runtime generator unlocks happen after loading is complete.
	# Connecting here means offline simulation cannot modify
	# the UI while the initial UI is still being constructed.
	simulation.generator_unlocked.connect(
		_on_generator_unlocked
	)

	loading_screen.set_status(
		"Realm awakened."
	)
	loading_screen.set_progress(
		1.0
	)

	await get_tree().process_frame

	is_loading = false
	loading_screen.visible = false
	if pending_offline_achievement_ids.size() > 0 and not $OfflineResultsPanel.visible:
		_show_pending_offline_achievements()
	_start_ambient_audio()


func _create_realm_view() -> void:
	realm_view = realm_view_scene.instantiate()
	realm_view.name = "RealmView"
	realm_view.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	realm_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	realm_view.z_index = -10

	add_child(realm_view)
	realm_view.setup(state)
	realm_view.generator_selected.connect(
		_on_generator_selection_requested
	)

# ============================================================
# GENERATORS
# ============================================================

func _create_initial_generator_panels() -> void:
	for generator in state.generators.values():
		if not generator.unlocked:
			continue

		_create_generator_panel(
			generator.definition.id
		)


func _create_generator_panel(
	generator_id: String
	) -> void:

	var generator = state.get_generator(
		generator_id
	)

	if generator == null:
		return

	if not generator.unlocked:
		return

	var generator_container = (
		$GeneratorScroll/GeneratorContainer
	)

	# Prevent duplicates.
	for child in generator_container.get_children():
		if child is GeneratorPanel:
			if child.generator_id == generator_id:
				return

	var generator_panel = (
		generator_panel_scene.instantiate()
	)

	generator_container.add_child(
		generator_panel
	)

	generator_panel.setup(
		state,
		input_handler,
		generator_id
	)
	generator_panel.upgrades_requested.connect(
		_on_generator_upgrades_requested
	)
	generator_panel.selection_requested.connect(
		_on_generator_panel_selection_requested
	)
	generator_panel.upgrade_automation_changed.connect(
		_on_upgrade_automation_settings_changed
	)
	generator_panel.generator_purchased.connect(
		_play_ui_purchase
	)
	# Preserve the original generator order.
	var target_index := 0

	for existing_generator in state.generators.values():
		if existing_generator.definition.id == generator_id:
			break

		if existing_generator.unlocked:
			target_index += 1

	generator_container.move_child(
		generator_panel,
		target_index
	)

	generator_panel.set_selected(
		generator_id == selected_generator_id
	)
	generator_panel.visible = generator_list_mode or generator_id == selected_generator_id



# ============================================================
# GENERATOR SELECTION
# ============================================================

func _initialize_generator_selection() -> void:
	if selected_generator_id != "":
		_set_selected_generator(selected_generator_id)
		return

	for generator in state.generators.values():
		if generator.unlocked:
			_set_selected_generator(generator.definition.id)
			return

	_set_selected_generator("")


func _on_generator_panel_selection_requested(generator_id: String) -> void:
	# In focused mode, clicking the current panel opens the full list
	# without losing the current generator selection.
	if generator_id == selected_generator_id:
		if not generator_list_mode:
			generator_list_mode = true
			$NavigationTitlePanel/NavigationTitle.text = "GENERATORS"
			$GeneratorsButton.text = "GENERATORS"
			$OptionsPanel.hide()
			$StatsPanel.hide()
			$UpgradeScroll.hide()
			$PrestigePanel.hide()
			$AchievementPanel.hide()
			selected_upgrade_generator_id = ""
			if generator_upgrade_tree != null:
				generator_upgrade_tree.hide()
			_refresh_generator_panel_visibility()
		else:
			# Clicking the focused generator in the list returns to its panel.
			generator_list_mode = false
			$NavigationTitlePanel/NavigationTitle.text = "GENERATOR"
			_refresh_generator_panel_visibility()
		return

	# Choosing another generator from the list returns to focused mode.
	generator_list_mode = false
	_on_generator_selection_requested(generator_id)


func _on_generator_selection_requested(generator_id: String) -> void:
	# Empty-space clicks in RealmView clear focus without touching navigation.
	if generator_id == "":
		_deselect_generator()
		return

	$NavigationTitlePanel/NavigationTitle.text = "GENERATOR"
	# Focusing a machine takes priority over every navigation panel.
	$StatsPanel.hide()
	$UpgradeScroll.hide()
	$PrestigePanel.hide()
	$OptionsPanel.hide()
	$AchievementPanel.hide()

	selected_upgrade_generator_id = ""
	$UpgradeScroll.offset_top = 112.0
	$UpgradeScroll.offset_right = 655.0
	_update_upgrade_view()

	# Clicking the active machine again returns to the unobstructed realm.
	if generator_id == selected_generator_id:
		_deselect_generator()
		return

	_set_selected_generator(generator_id)


func _set_selected_generator(generator_id: String) -> void:
	if generator_id != "":
		var generator = state.get_generator(generator_id)
		if generator == null or not generator.unlocked:
			return

	selected_generator_id = generator_id
	var selected_panel: GeneratorPanel = _get_generator_panel(generator_id)
	if selected_panel != null:
		selected_panel.mark_seen()

	if realm_view != null:
		realm_view.set_selected_generator(selected_generator_id)

	_refresh_generator_panel_visibility()


func _deselect_generator() -> void:
	generator_list_mode = false
	_clear_generator_focus()
	$UpgradeScroll.hide()


func _clear_generator_focus() -> void:
	selected_generator_id = ""
	selected_upgrade_generator_id = ""
	if generator_upgrade_tree != null:
		generator_upgrade_tree.hide()

	if realm_view != null:
		realm_view.set_selected_generator("")

	$GeneratorsButton.text = "GENERATORS"
	_refresh_generator_panel_visibility()


# ============================================================
# UPGRADE UI
# ============================================================

func _create_initial_upgrade_ui() -> void:
	var automatic_upgrades: Array = []

	for upgrade in state.upgrades.values():
		
		if upgrade.definition.generator_id != "":
			continue
		
		if not state.upgrade_system.is_upgrade_visible(
			upgrade
			):
			continue
		
		if upgrade.definition.automatic:
			automatic_upgrades.append(
				upgrade
			)
			continue

		add_upgrade_panel(
			upgrade
		)

	_create_initial_effects_ui(
		automatic_upgrades
	)



func add_upgrade_panel(
	upgrade: Upgrade
	) -> void:

	# Generator-specific upgrades belong only in their generator tree.
	if upgrade.definition.generator_id != "":
		return

	if upgrade_panels.has(
		upgrade.definition.id
	):
		return

	if not state.upgrade_system.is_upgrade_visible(upgrade):
		return

	var group_id = (
		upgrade.definition.upgrade_group_id
	)

	if not upgrade_flows.has(
		group_id
	):
		create_upgrade_group(
			group_id
		)

	var upgrade_flow = (
		upgrade_flows[group_id]
	)

	var panel = (
		upgrade_panel_scene.instantiate()
	)

	panel.custom_minimum_size = Vector2(44, 44)
	panel.size = Vector2(44, 44)

	upgrade_flow.add_child(
		panel
	)

	panel.setup(
		state,
		simulation,
		input_handler,
		upgrade.definition.id,
		$UpgradeInfoPopup
	)
	panel.purchase_succeeded.connect(
		_play_ui_purchase
	)

	upgrade_panels[
		upgrade.definition.id
	] = panel



func _update_upgrade_view() -> void:

	var general_container = (
		$UpgradeScroll/UpgradeContent/GeneralUpgradeContainer
	)

	var generator_container = (
		$UpgradeScroll/UpgradeContent/GeneratorUpgradeContainer
	)

	if selected_upgrade_generator_id == "":
		general_container.visible = true
		generator_container.visible = false
		if generator_upgrade_tree != null:
			generator_upgrade_tree.hide()
		return

	general_container.visible = false
	generator_container.visible = false
	$UpgradeScroll.hide()

	if generator_upgrade_tree != null:
		generator_upgrade_tree.show()
		generator_upgrade_tree.setup(
			state,
			simulation,
			input_handler,
			selected_upgrade_generator_id,
			$UpgradeInfoPopup
		)


func create_upgrade_group(
	group_id: String
	) -> void:

	if upgrade_flows.has(
		group_id
	):
		return

	var group_container = VBoxContainer.new()

	group_container.name = (
		"UpgradeGroup_%s" % group_id
	)

	group_container.add_theme_constant_override(
		"separation",
		6
	)

	$UpgradeScroll/UpgradeContent/GeneralUpgradeContainer.add_child(
		group_container
	)

	var group_label = Label.new()

	var group = state.get_upgrade_group(
		group_id
	)

	if group != null:
		group_label.text = (
			group.display_name
		)
	else:
		group_label.text = "General"

	group_container.add_child(
		group_label
	)

	var upgrade_flow = HFlowContainer.new()

	upgrade_flow.name = "UpgradeFlow"

	upgrade_flow.add_theme_constant_override(
		"h_separation",
		3
	)

	upgrade_flow.add_theme_constant_override(
		"v_separation",
		3
	)

	group_container.add_child(
		upgrade_flow
	)

	upgrade_group_containers[
		group_id
	] = group_container

	upgrade_flows[
		group_id
	] = upgrade_flow


# ============================================================
# AUTOMATIC UPGRADES / EFFECTS
# ============================================================

func _create_initial_effects_ui(
	automatic_upgrades: Array
	) -> void:

	if automatic_upgrades.is_empty():
		return

	_create_effects_container()

	for upgrade in automatic_upgrades:
		add_automatic_upgrade_panel(
			upgrade
		)


func _create_effects_container() -> void:
	if effects_flow != null:
		return

	var effects_label = Label.new()

	effects_label.text = "EFFECTS"

	effects_label.custom_minimum_size = Vector2(
		0,
		35
	)

	effects_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	$UpgradeScroll/UpgradeContent/GeneralUpgradeContainer.add_child(
		effects_label
	)

	effects_flow = HFlowContainer.new()

	effects_flow.name = "EffectsFlow"

	effects_flow.custom_minimum_size = Vector2(
		0,
		70
	)

	effects_flow.add_theme_constant_override(
		"h_separation",
		3
	)

	effects_flow.add_theme_constant_override(
		"v_separation",
		3
	)

	$UpgradeScroll/UpgradeContent/GeneralUpgradeContainer.add_child(
		effects_flow
	)



func add_automatic_upgrade_panel(
	upgrade: Upgrade
	) -> void:

	# Generator-specific automatic upgrades belong only in their generator tree.
	if upgrade.definition.generator_id != "":
		return

	if upgrade_panels.has(
		upgrade.definition.id
	):
		return

	if not state.upgrade_system.is_upgrade_visible(upgrade):
		return

	_create_effects_container()

	var panel = (
		upgrade_panel_scene.instantiate()
	)

	panel.custom_minimum_size = Vector2(44, 44)
	panel.size = Vector2(44, 44)

	effects_flow.add_child(panel)

	panel.setup(
		state,
		simulation,
		input_handler,
		upgrade.definition.id,
		$UpgradeInfoPopup
	)
	panel.purchase_succeeded.connect(
		_play_ui_purchase
	)

	upgrade_panels[
		upgrade.definition.id
	] = panel



# ============================================================
# GENERATOR UNLOCK EVENT
# ============================================================

func _on_generator_unlocked(
	generator_id: String
	) -> void:

	_play_ui_unlock()

	# Keep the unlock toast for every generator, including Infernal Forge.
	# Infernal Forge is excluded from the generic island marker and particles.
	var generator: Generator = state.get_generator(generator_id)
	if generator != null:
		$AchievementToast.show_generator_unlocked(
			generator.definition.display_name,
			"A new machine is ready to build. Select it on the island or in Generators to buy its first level."
		)

	# Add the newly unlocked generator without changing the current selection.
	_create_generator_panel(
		generator_id
	)
	var generator_panel: GeneratorPanel = _get_generator_panel(generator_id)
	if generator_id != "infernal_forge" and generator_panel != null:
		generator_panel.mark_new_unlock()
	_refresh_generator_panel_visibility()

	# Add all upgrades that become visible because
	# this generator is now unlocked.
	for upgrade in state.upgrades.values():
		if not state.upgrade_system.is_upgrade_visible(upgrade):
			continue

		if upgrade.definition.generator_id != generator_id:
			continue

		if upgrade.definition.automatic:
			add_automatic_upgrade_panel(
				upgrade
			)
		else:
			add_upgrade_panel(
				upgrade
			)


func _on_technology_unlocked(
	technology_id: String
	) -> void:

	for upgrade in state.upgrades.values():
		if not state.upgrade_system.is_upgrade_visible(upgrade):
			continue
		
		if upgrade_panels.has(
			upgrade.definition.id
		):
			continue
		
		if upgrade.definition.technology_id != technology_id:
			continue
		
		if upgrade.definition.automatic:
			add_automatic_upgrade_panel(
				upgrade
			)
		else:
			add_upgrade_panel(
				upgrade
			)

# ============================================================
# MAIN LOOP
# ============================================================

func _process(
	delta: float
	) -> void:

	if is_loading:
		return

	time_manager.update(
		delta
	)
	state.achievement_manager.update(state)
	if $AchievementPanel.visible:
		$AchievementPanel.refresh()

	_update_navigation_title_visibility()
	_update_ambient_audio(delta)


func _update_navigation_title_visibility() -> void:
	# Keep the fixed title visible only while its corresponding
	# navigation content is open. This also handles menus closed
	# by their own toggle buttons or by other navigation actions.
	$NavigationTitlePanel.visible = (
		$GeneratorScroll.visible
		or $UpgradeScroll.visible
		or $StatsPanel.visible
		or $PrestigePanel.visible
		or $OptionsPanel.visible
		or $AchievementPanel.visible
	)


# ============================================================
# BUTTONS
# ============================================================

func _refresh_generator_panel_visibility() -> void:
	var generator_container: Node = $GeneratorScroll/GeneratorContainer
	var selected_panel: GeneratorPanel

	for child in generator_container.get_children():
		if not child is GeneratorPanel:
			continue

		child.visible = generator_list_mode or child.generator_id == selected_generator_id
		child.set_selected(child.generator_id == selected_generator_id)

		if child.generator_id == selected_generator_id:
			selected_panel = child

	# In focused mode, no selection means no generator panel at all.
	$GeneratorScroll.visible = generator_list_mode or selected_generator_id != ""

	if generator_list_mode and selected_panel != null:
		$GeneratorScroll.ensure_control_visible(selected_panel)
	elif not generator_list_mode:
		$GeneratorScroll.scroll_vertical = 0


func _on_generators_button_pressed() -> void:
	$NavigationTitlePanel/NavigationTitle.text = "GENERATORS"
	generator_list_mode = not generator_list_mode
	_clear_generator_focus()

	$OptionsPanel.hide()
	$StatsPanel.hide()
	$UpgradeScroll.hide()
	$PrestigePanel.hide()
	$AchievementPanel.hide()
	_refresh_generator_panel_visibility()

	$GeneratorsButton.text = "GENERATORS"


func _on_offline_achievement_unlocked(achievement_id: String) -> void:
	if not pending_offline_achievement_ids.has(achievement_id):
		pending_offline_achievement_ids.append(achievement_id)


func _on_offline_results_closed() -> void:
	_show_pending_offline_achievements()


func _show_pending_offline_achievements() -> void:
	var achievement_ids: Array[String] = pending_offline_achievement_ids.duplicate()
	pending_offline_achievement_ids.clear()

	for achievement_id in achievement_ids:
		_on_achievement_unlocked(achievement_id)


func _on_achievement_unlocked(achievement_id: String) -> void:
	var definition: Dictionary = AchievementRegistry.get_definition(
		achievement_id
	)
	if definition.is_empty():
		return

	$AchievementToast.show_achievement(
		str(definition.get("title", achievement_id)),
		str(definition.get("description", ""))
	)
	_play_ui_unlock()


func _on_achievements_button_pressed() -> void:
	$NavigationTitlePanel/NavigationTitle.text = "ACHIEVEMENTS"
	var should_open: bool = not $AchievementPanel.visible
	generator_list_mode = false
	_clear_generator_focus()
	$GeneratorsButton.text = "GENERATORS"
	$AchievementPanel.visible = should_open

	if should_open:
		$OptionsPanel.hide()
		$StatsPanel.hide()
		$UpgradeScroll.hide()
		$PrestigePanel.hide()
		$GeneratorScroll.hide()
	else:
		$GeneratorScroll.show()
		_refresh_generator_panel_visibility()


func _on_options_button_pressed() -> void:
	$NavigationTitlePanel/NavigationTitle.text = "OPTIONS"
	var should_open: bool = not $OptionsPanel.visible
	generator_list_mode = false
	_clear_generator_focus()

	$OptionsPanel.visible = should_open
	$GeneratorsButton.text = "GENERATORS"

	if should_open:
		$StatsPanel.hide()
		$UpgradeScroll.hide()
		$PrestigePanel.hide()
		$AchievementPanel.hide()
		$GeneratorScroll.hide()
	else:
		$GeneratorScroll.show()
		_refresh_generator_panel_visibility()


func _on_options_close_button_pressed() -> void:
	$OptionsPanel.hide()
	$GeneratorScroll.show()
	_refresh_generator_panel_visibility()


func _on_quit_game_button_pressed() -> void:
	if save_manager != null and state != null and time_manager != null:
		save_manager.save_game(
			state,
			time_manager
		)

	get_tree().quit()


func _on_visual_effects_toggled(enabled: bool) -> void:
	visual_effects_enabled = enabled
	_save_visual_settings()

	if realm_view != null:
		realm_view.set_visual_effects_enabled(enabled)


func _on_ui_sounds_toggled(enabled: bool) -> void:
	ui_sounds_enabled = enabled
	_save_ui_sound_settings()


func _on_ambient_audio_toggled(enabled: bool) -> void:
	ambient_enabled = enabled

	if ambient_enabled:
		_start_ambient_audio()
	else:
		_stop_ambient_audio()

	_save_audio_settings()


func _on_master_volume_changed(value: float) -> void:
	master_volume_percent = value
	_update_master_volume_label()
	_apply_master_volume()
	_save_audio_settings()


func _update_master_volume_label() -> void:
	$OptionsPanel/OptionsContent/MasterVolumeLabel.text = "MASTER VOLUME: %d%%" % int(round(master_volume_percent))


func _apply_master_volume() -> void:
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	if master_bus_index < 0:
		return

	if master_volume_percent <= 0.0:
		AudioServer.set_bus_volume_db(master_bus_index, -80.0)
	else:
		AudioServer.set_bus_volume_db(
			master_bus_index,
			linear_to_db(master_volume_percent / 100.0)
		)


func _unhandled_key_input(event: InputEvent) -> void:
	if state == null or not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if realm_view != null and realm_view.realm_layout_editor_controller.layout_mode:
		return

	if (
		$OptionsPanel.visible
		or $StatsPanel.visible
		or $UpgradeScroll.visible
		or (generator_upgrade_tree != null and generator_upgrade_tree.visible)
		or $PrestigePanel.visible
		or $OfflineResultsPanel.visible
	):
		return

	var focus_owner := get_viewport().gui_get_focus_owner()

	if key_event.keycode == KEY_ESCAPE:
		if selected_generator_id != "" or generator_list_mode:
			_deselect_generator()
			get_viewport().set_input_as_handled()
		return

	# Let focused UI controls own arrow keys instead of also cycling generators.
	if focus_owner != null:
		return

	if key_event.keycode != KEY_UP and key_event.keycode != KEY_DOWN:
		return

	var unlocked_ids: Array[String] = []
	for generator in state.generators.values():
		if generator.unlocked:
			unlocked_ids.append(generator.definition.id)

	if unlocked_ids.size() <= 1:
		return

	var current_index := unlocked_ids.find(selected_generator_id)
	if current_index < 0:
		current_index = (
			unlocked_ids.size() - 1
			if key_event.keycode == KEY_UP
			else 0
		)
	elif key_event.keycode == KEY_UP:
		current_index = (current_index - 1 + unlocked_ids.size()) % unlocked_ids.size()
	else:
		current_index = (current_index + 1) % unlocked_ids.size()

	_set_selected_generator(unlocked_ids[current_index])
	get_viewport().set_input_as_handled()


func _get_generator_panel(generator_id: String) -> GeneratorPanel:
	var generator_container: Node = $GeneratorScroll/GeneratorContainer
	for child in generator_container.get_children():
		if child is GeneratorPanel and child.generator_id == generator_id:
			return child
	return null


func _input(event: InputEvent) -> void:
	if not ui_sounds_enabled or not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var hovered: Control = get_viewport().gui_get_hovered_control()
	while hovered != null:
		if hovered is BaseButton:
			if hovered.name == "UpgradeButton" or hovered.name == "BuyButton":
				return
			_play_ui_click()
			return
		hovered = hovered.get_parent() as Control


func _setup_ambient_audio() -> void:
	ambient_players.clear()

	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "AmbientPlayer%d" % i
		player.bus = "Master"
		player.volume_db = 0.0
		add_child(player)
		ambient_players.append(player)


func _start_ambient_audio() -> void:
	if not ambient_enabled or ambient_players.size() != 2:
		return

	_stop_ambient_audio()
	ambient_track_order.clear()
	for i in range(AMBIENT_TRACKS.size()):
		ambient_track_order.append(i)
	ambient_track_order.shuffle()
	ambient_track_order_index = 0
	ambient_current_track_index = -1
	ambient_next_track_index = -1
	ambient_active_player_index = 0

	ambient_current_track_index = _get_next_ambient_track_index()
	var player := ambient_players[ambient_active_player_index]
	player.stream = AMBIENT_TRACKS[ambient_current_track_index]
	player.volume_db = 0.0
	player.play()


func _stop_ambient_audio() -> void:
	for player in ambient_players:
		player.stop()
		player.stream = null
		player.volume_db = 0.0

	ambient_crossfade_active = false
	ambient_crossfade_elapsed = 0.0
	ambient_next_track_index = -1


func _get_next_ambient_track_index() -> int:
	if ambient_track_order_index >= ambient_track_order.size():
		ambient_track_order.shuffle()

		# Avoid repeating the previous track when reshuffling the playlist.
		if (
			ambient_track_order.size() > 1
			and ambient_track_order[0] == ambient_current_track_index
		):
			var swap_index: int = ambient_track_order[0]
			ambient_track_order[0] = ambient_track_order[1]
			ambient_track_order[1] = swap_index

		ambient_track_order_index = 0

	var track_index: int = ambient_track_order[ambient_track_order_index]
	ambient_track_order_index += 1
	return track_index


func _update_ambient_audio(delta: float) -> void:
	if not ambient_enabled or ambient_players.size() != 2:
		return

	if ambient_crossfade_active:
		ambient_crossfade_elapsed += delta
		var progress: float = clampf(
			ambient_crossfade_elapsed / AMBIENT_CROSSFADE_DURATION,
			0.0,
			1.0
		)

		var outgoing_player := ambient_players[ambient_active_player_index]
		var incoming_player_index: int = 1 - ambient_active_player_index
		var incoming_player := ambient_players[incoming_player_index]

		outgoing_player.volume_db = linear_to_db(maxf(1.0 - progress, 0.001))
		incoming_player.volume_db = linear_to_db(maxf(progress, 0.001))

		if progress >= 1.0:
			outgoing_player.stop()
			outgoing_player.stream = null
			outgoing_player.volume_db = 0.0
			incoming_player.volume_db = 0.0
			ambient_active_player_index = incoming_player_index
			ambient_current_track_index = ambient_next_track_index
			ambient_next_track_index = -1
			ambient_crossfade_active = false
			ambient_crossfade_elapsed = 0.0
		return

	var active_player := ambient_players[ambient_active_player_index]
	if active_player.stream == null:
		return

	var track_length: float = active_player.stream.get_length()
	if track_length <= 0.0:
		return

	var remaining_time: float = track_length - active_player.get_playback_position()
	if remaining_time <= AMBIENT_CROSSFADE_DURATION:
		ambient_next_track_index = _get_next_ambient_track_index()
		var incoming_player := ambient_players[1 - ambient_active_player_index]
		incoming_player.stream = AMBIENT_TRACKS[ambient_next_track_index]
		incoming_player.volume_db = -60.0
		incoming_player.play()
		ambient_crossfade_active = true
		ambient_crossfade_elapsed = 0.0


func _setup_ui_audio() -> void:
	ui_click_player = AudioStreamPlayer.new()
	ui_click_player.name = "UIClickPlayer"
	ui_click_player.bus = "Master"
	ui_click_player.stream = _create_ui_click_stream()
	add_child(ui_click_player)

	ui_purchase_player = AudioStreamPlayer.new()
	ui_purchase_player.name = "UIPurchasePlayer"
	ui_purchase_player.bus = "Master"
	ui_purchase_player.stream = _create_ui_tone_stream(760.0, 1180.0, 0.10, 0.22)
	add_child(ui_purchase_player)

	ui_unlock_player = AudioStreamPlayer.new()
	ui_unlock_player.name = "UIUnlockPlayer"
	ui_unlock_player.bus = "Master"
	ui_unlock_player.stream = _create_ui_tone_stream(480.0, 1320.0, 0.28, 0.25)
	add_child(ui_unlock_player)


func _create_ui_tone_stream(
	start_frequency: float,
	end_frequency: float,
	duration: float,
	amplitude: float
	) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var sample_count: int = int(sample_rate * duration)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)

	for i in range(sample_count):
		var progress: float = float(i) / float(sample_count)
		var frequency: float = lerp(start_frequency, end_frequency, progress)
		var envelope: float = pow(1.0 - progress, 2.0)
		var fundamental: float = sin(TAU * frequency * float(i) / float(sample_rate))
		var harmonic: float = sin(TAU * frequency * 2.0 * float(i) / float(sample_rate)) * 0.22
		var sample: int = int((fundamental + harmonic) * envelope * amplitude * 16000.0)
		if sample < 0:
			sample += 65536
		samples[i * 2] = sample & 0xFF
		samples[i * 2 + 1] = (sample >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = samples
	return stream


func _create_ui_click_stream() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var sample_count: int = 1102
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)

	for i in range(sample_count):
		var progress: float = float(i) / float(sample_count)
		var frequency: float = lerp(1450.0, 620.0, progress)
		var envelope: float = pow(1.0 - progress, 3.0)
		var sample: int = int(sin(TAU * frequency * float(i) / float(sample_rate)) * envelope * 5200.0)
		if sample < 0:
			sample += 65536
		samples[i * 2] = sample & 0xFF
		samples[i * 2 + 1] = (sample >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = samples
	return stream


func _play_ui_click() -> void:
	if ui_click_player == null or not ui_sounds_enabled:
		return
	ui_click_player.play()


func _play_ui_purchase() -> void:
	if ui_purchase_player == null or not ui_sounds_enabled:
		return
	ui_purchase_player.play()


func _play_ui_unlock() -> void:
	if ui_unlock_player == null or not ui_sounds_enabled:
		return
	ui_unlock_player.play()


func _load_visual_settings() -> void:
	var config := ConfigFile.new()
	var error: Error = config.load("user://settings.cfg")
	if error == OK:
		visual_effects_enabled = config.get_value(
			"graphics",
			"animated_visual_effects",
			true
		)
		ui_sounds_enabled = config.get_value(
			"audio",
			"ui_sounds_enabled",
			true
		)
		master_volume_percent = clampf(
			float(config.get_value("audio", "master_volume_percent", 70.0)),
			0.0,
			100.0
		)
		ambient_enabled = bool(config.get_value("audio", "ambient_enabled", true))


func _save_visual_settings() -> void:
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value(
		"graphics",
		"animated_visual_effects",
		visual_effects_enabled
	)
	var error: Error = config.save("user://settings.cfg")
	if error != OK:
		push_warning("Could not save visual settings: %s" % error)


func _save_ui_sound_settings() -> void:
	_save_audio_settings()


func _save_audio_settings() -> void:
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value(
		"audio",
		"ui_sounds_enabled",
		ui_sounds_enabled
	)
	config.set_value(
		"audio",
		"master_volume_percent",
		master_volume_percent
	)
	config.set_value(
		"audio",
		"ambient_enabled",
		ambient_enabled
	)
	var error: Error = config.save("user://settings.cfg")
	if error != OK:
		push_warning("Could not save audio settings: %s" % error)


func _on_rub_button_pressed() -> void:

	save_manager.save_game(
		state,
		time_manager
	)

	print(
		"Game Saved."
	)


func _on_stats_button_pressed() -> void:
	$NavigationTitlePanel/NavigationTitle.text = "STATISTICS"
	var should_open: bool = not $StatsPanel.visible
	generator_list_mode = false
	_clear_generator_focus()
	$GeneratorsButton.text = "GENERATORS"

	$StatsPanel.visible = should_open

	if should_open:
		$OptionsPanel.hide()
		$UpgradeScroll.hide()
		$PrestigePanel.hide()
		$AchievementPanel.hide()
		$GeneratorScroll.hide()



func _on_upgrades_button_pressed() -> void:
	$NavigationTitlePanel/NavigationTitle.text = "UPGRADES"
	var general_upgrades_are_open: bool = (
		$UpgradeScroll.visible
		and selected_upgrade_generator_id == ""
	)
	generator_list_mode = false
	_clear_generator_focus()
	$GeneratorsButton.text = "GENERATORS"

	$OptionsPanel.hide()
	$StatsPanel.hide()
	$PrestigePanel.hide()
	$AchievementPanel.hide()
	$GeneratorScroll.hide()
	selected_upgrade_generator_id = ""

	if general_upgrades_are_open:
		$UpgradeScroll.hide()
		_update_upgrade_view()
		return

	$UpgradeScroll.show()
	$UpgradeScroll.offset_left = 12.0
	$UpgradeScroll.offset_top = 112.0
	$UpgradeScroll.offset_right = 655.0
	_update_upgrade_view()

func _on_prestige_requested() -> void:
	$StatsPanel.hide()
	$UpgradeScroll.hide()
	if generator_upgrade_tree != null:
		generator_upgrade_tree.hide()
	$GeneratorScroll.hide()
	$PrestigePanel.hide()

	prestige_animation.play()


func _on_prestige_destruction_complete() -> void:
	$PrestigePanel.perform_smash()

	$GeneratorScroll.show()
	
func _on_prestige_button_pressed() -> void:
	$NavigationTitlePanel/NavigationTitle.text = "REALM"
	var should_open: bool = not $PrestigePanel.visible
	generator_list_mode = false
	_clear_generator_focus()
	$GeneratorsButton.text = "GENERATORS"

	$PrestigePanel.visible = should_open

	if should_open:
		$OptionsPanel.hide()
		$StatsPanel.hide()
		$UpgradeScroll.hide()
		$AchievementPanel.hide()
		$GeneratorScroll.hide()


func _on_run_reset() -> void:
	# ------------------------------------------------------------
	# Rebuild the physical realm
	# ------------------------------------------------------------

	if realm_view != null:
		realm_view.rebuild_realm(
			state.realm_layout
		)

	# ------------------------------------------------------------
	# Rebuild UI
	# ------------------------------------------------------------

	await _rebuild_generator_ui()
	await _rebuild_upgrade_ui()

func _rebuild_generator_ui() -> void:
	var generator_container = (
		$GeneratorScroll/GeneratorContainer
	)
	
	for child in generator_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	_create_initial_generator_panels()
	_initialize_generator_selection()
	_refresh_generator_panel_visibility()
	
func _rebuild_upgrade_ui() -> void:
	var upgrade_container = (
		$UpgradeScroll/UpgradeContent/GeneralUpgradeContainer
	)
	
	for child in upgrade_container.get_children():
		child.queue_free()
	
	upgrade_group_containers.clear()
	upgrade_flows.clear()
	upgrade_panels.clear()
	effects_flow = null
	
	await get_tree().process_frame
	
	_create_initial_upgrade_ui()


func _on_generator_upgrades_requested(
	generator_id: String
	) -> void:

	$OptionsPanel.hide()
	$StatsPanel.hide()
	$PrestigePanel.hide()

	# Clicking UPGRADES in list mode enters focused mode for that generator.
	if (
		generator_upgrade_tree != null
		and generator_upgrade_tree.visible
		and selected_upgrade_generator_id == generator_id
		and not generator_list_mode
	):
		generator_upgrade_tree.hide()
		selected_upgrade_generator_id = ""
		return

	generator_list_mode = false
	$GeneratorsButton.text = "GENERATORS"
	_set_selected_generator(generator_id)

	$GeneratorScroll.show()
	$UpgradeScroll.hide()
	selected_upgrade_generator_id = generator_id

	_update_upgrade_view()
	_position_generator_upgrade_tree()


func _position_generator_upgrade_tree() -> void:
	var selected_panel := _get_generator_panel(selected_generator_id)
	if selected_panel == null:
		return

	var panel_height: float = maxf(
		selected_panel.size.y,
		selected_panel.custom_minimum_size.y
	)

	generator_upgrade_tree.offset_left = 12.0
	generator_upgrade_tree.offset_top = $GeneratorScroll.offset_top + panel_height + 8.0
	generator_upgrade_tree.offset_right = 462.0
	generator_upgrade_tree.offset_bottom = 590.0

func _create_generator_upgrade_tree() -> void:

	if generator_upgrade_tree != null:
		return

	generator_upgrade_tree = (
		generator_upgrade_tree_scene.instantiate()
	)

	add_child(generator_upgrade_tree)
	generator_upgrade_tree.hide()
	generator_upgrade_tree.automation_settings_changed.connect(
		_on_upgrade_automation_settings_changed
	)
	generator_upgrade_tree.purchase_succeeded.connect(
		_play_ui_purchase
	)


func _on_upgrade_automation_settings_changed() -> void:
	if save_manager == null or time_manager == null:
		return

	save_manager.save_game(
		state,
		time_manager
	)


func _on_offline_simulation_progress(
	current_tick: int,
	total_ticks: int
	) -> void:
	loading_screen.set_simulation_tick(
		current_tick,
		total_ticks
	)


func _get_resource_display_name(
	resource_id: String
	) -> String:

	match resource_id:
		ResourceIds.HEAT:
			return "Heat"

		ResourceIds.MATTER:
			return "Matter"

		ResourceIds.ASH:
			return "Ash"

		ResourceIds.CRYSTALIZED_FLAME:
			return "Crystallized Flame"

		_:
			return resource_id


func _format_resource_amount(
	amount: float
	) -> String:
	return NumberFormatter.format(amount)
	
func _build_offline_results(
	offline_seconds: float
	) -> String:

	var statistics = time_manager.simulation_statistics

	var lines: Array[String] = []

	lines.append("OFFLINE RESULTS")
	lines.append("")

	var resource_ids = [
		ResourceIds.HEAT,
		ResourceIds.MATTER,
		ResourceIds.ASH,
		ResourceIds.CRYSTALIZED_FLAME
	]

	for resource_id in resource_ids:
		var produced = statistics.get_total_produced(
			resource_id
		)

		var consumed = statistics.get_total_consumed(
			resource_id
		)

		var lost = statistics.get_total_lost(
			resource_id
		)

		if (
			is_zero_approx(produced)
			and is_zero_approx(consumed)
			and is_zero_approx(lost)
		):
			continue

		lines.append(
			"%s:" % _get_resource_display_name(resource_id)
		)

		lines.append(
			"  Produced: %s" % _format_resource_amount(produced)
		)

		lines.append(
			"  Consumed: %s" % _format_resource_amount(consumed)
		)

		lines.append(
			"  Lost: %s" % _format_resource_amount(lost)
		)

		lines.append("")

	var overflow = statistics.get_total_overflow()

	if not is_zero_approx(overflow):
		lines.append(
			"Heat Overflow: %s" % _format_resource_amount(overflow)
		)

	lines.append("")
	lines.append("LAVA MITE DORMANCY")

	var dormancy_delay = (
		state.get_lava_mite_dormancy_delay()
	)

	var dormancy_duration = (
		state.get_lava_mite_dormancy_duration()
	)

	var dormancy_max_penalty = (
		state.get_lava_mite_dormancy_max_penalty()
	)

	var dormancy_penalty = (
		time_manager.get_dormancy_penalty(
			offline_seconds
		)
	)

	lines.append(
		"  Delay: %s" % _format_duration(
			dormancy_delay
		)
	)

	lines.append(
		"  Time to maximum: %s" % _format_duration(
			dormancy_duration
		)
	)

	lines.append(
		"  Maximum penalty: %.1f%%" % (
			dormancy_max_penalty * 100.0
		)
	)

	lines.append(
		"  Simulated penalty: %.1f%%" % (
			dormancy_penalty * 100.0
		)
	)

	return "\n".join(lines)
	
func _format_duration(
	seconds: float
	) -> String:

	if seconds < 60.0:
		return "%.0fs" % seconds

	var total_minutes: int = floori(seconds / 60.0)
	var minutes: int = total_minutes % 60
	var hours: int = floori(float(total_minutes) / 60.0)

	if hours > 0:
		return "%dh %02dm" % [
			hours,
			minutes
		]

	return "%dm" % minutes
