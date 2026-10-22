
extends Control


var is_loading: bool = true
var is_new_save: bool = false
var is_intro_playing: bool = false
const INTRO_STARTING_HEAT: float = 15.0
const VISUAL_EFFECT_OFF: int = 0
const VISUAL_EFFECT_LOW: int = 1
const VISUAL_EFFECT_MEDIUM: int = 2
const VISUAL_EFFECT_HIGH: int = 3
var visual_effect_quality: int = VISUAL_EFFECT_MEDIUM
var visual_effects_enabled: bool:
	get:
		return visual_effect_quality > VISUAL_EFFECT_OFF
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
var tutorial_manager: TutorialManager
var assistant_popup: AssistantPopup
var pending_offline_achievement_ids: Array[String] = []

var upgrade_group_containers: Dictionary = {}
var upgrade_flows: Dictionary = {}
var upgrade_panels: Dictionary = {}

var selected_upgrade_generator_id: String = ""
var selected_generator_id: String = ""
var generator_list_mode: bool = false

var effects_flow: HFlowContainer
var generator_unlocks_flow: HFlowContainer
var prestige_animation: PrestigeAnimation
var reliquary_window: PanelContainer
var reliquary_panel: ReliquaryPanel

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
const space_background_script: Script = preload("res://RealmView/SpaceBackground.gd")

var space_background: TextureRect
var realm_view: RealmView

@onready var loading_screen: Control = $LoadingScreen
@onready var offline_results_panel: Control = $OfflineResultsPanel

func _ready() -> void:
	_update_navigation_buttons("GeneratorsButton")
	_style_options_panel()
	_add_tutorial_archive_button()
	$OfflineResultsPanel.results_closed.connect(
		_on_offline_results_closed
	)
	_load_visual_settings()
	var visual_quality_picker: OptionButton = $OptionsPanel/OptionsContent/VisualEffectsQualityOption
	visual_quality_picker.clear()
	visual_quality_picker.add_item("OFF", VISUAL_EFFECT_OFF)
	visual_quality_picker.add_item("LOW", VISUAL_EFFECT_LOW)
	visual_quality_picker.add_item("MEDIUM", VISUAL_EFFECT_MEDIUM)
	visual_quality_picker.add_item("HIGH", VISUAL_EFFECT_HIGH)
	visual_quality_picker.select(visual_effect_quality)
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
	realm_view.set_visual_effect_quality(visual_effect_quality)
	
	
		
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
	simulation.critical_crystallization_completed.connect(
		realm_view.play_critical_crystallization_event
	)
	simulation.generator_level_reduced.connect(
		realm_view.play_forge_level_reduction_event
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

	# Tutorial progress is stored separately so it survives realm resets.
	tutorial_manager = TutorialManager.new()
	add_child(tutorial_manager)
	assistant_popup = AssistantPopup.new()
	add_child(assistant_popup)
	tutorial_manager.tutorial_requested.connect(
		assistant_popup.show_tutorial
	)
	assistant_popup.tutorial_dismissed.connect(
		tutorial_manager.complete_tutorial
	)
	assistant_popup.tutorial_replay_requested.connect(
		tutorial_manager.replay_tutorial
	)
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

	# Only a genuinely absent save gets the opening sequence. Existing or invalid
	# save files must never receive the new-game starting gift.
	is_new_save = not FileAccess.file_exists("user://savegame.json")
	var loaded = save_manager.load_game(
		state,
		time_manager
	)
	if is_new_save and not loaded:
		var starting_generator = state.get_generator("atomic_friction")
		if starting_generator != null:
			starting_generator.level = 0
			starting_generator.unlocked = true
		state.set_resource_amount(ResourceIds.HEAT, 0.0)
	if loaded:
		# Stabilization is no longer part of the realm loop. Migrate any
		# saved countdown away and preserve the current allocation until Smash.
		time_manager.cancel_stabilization_countdown()
		if not state.prestige_planning:
			state.realm_stabilized = true
			state.realm_configuration.lock()
	state.achievement_manager.update(state)
	realm_view.rebuild_realm(
		state.realm_layout
	)

	if loaded:
		simulation.rebuild_upgrade_effects()

	if loaded and not state.prestige_planning:
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
	_create_reliquary_window()
	_update_navigation_buttons("GeneratorsButton")
	$PrestigePanel.technology_unlocked.connect(
		_on_technology_unlocked
	)
	$PrestigePanel.run_reset.connect(
		_on_run_reset
	)
	$PrestigePanel.planning_started.connect(
		_enter_prestige_planning_mode
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
	if is_new_save:
		await _play_new_game_intro()
	if state.prestige_planning:
		_enter_prestige_planning_mode()
	if pending_offline_achievement_ids.size() > 0 and not $OfflineResultsPanel.visible:
		_show_pending_offline_achievements()
	_start_ambient_audio()



func _play_new_game_intro() -> void:
	is_intro_playing = true
	_update_navigation_title_visibility()

	# Keep the intro cinematic: hide the regular interface without losing its
	# existing visibility state, while leaving the moving space background visible.
	var previous_visibility: Dictionary = {}
	for child in get_children():
		if child is Control and child != realm_view and child != space_background:
			previous_visibility[child] = child.visible
			child.hide()

	var realm_previous_visibility := realm_view.visible
	realm_view.hide()

	var overlay := ColorRect.new()
	overlay.name = "NewGameIntroOverlay"
	overlay.color = Color(0.008, 0.006, 0.012, 0.35)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 1000
	add_child(overlay)

	var text_label := Label.new()
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 30)
	text_label.add_theme_color_override("font_color", Color(0.92, 0.84, 0.77))
	text_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	text_label.position = Vector2(-420, -55)
	text_label.size = Vector2(840, 110)
	text_label.modulate.a = 0.0
	overlay.add_child(text_label)

	var intro_tween := create_tween()
	intro_tween.tween_interval(0.8)
	intro_tween.tween_property(text_label, "modulate:a", 1.0, 1.4)
	text_label.text = "There is only the dark void."
	await intro_tween.finished
	await get_tree().create_timer(1.4).timeout

	var second_tween := create_tween()
	second_tween.tween_property(text_label, "modulate:a", 0.0, 0.8)
	await second_tween.finished
	text_label.text = "But something new is awakening."
	var third_tween := create_tween()
	third_tween.tween_property(text_label, "modulate:a", 1.0, 1.2)
	await third_tween.finished
	await get_tree().create_timer(1.5).timeout

	var fourth_tween := create_tween()
	fourth_tween.tween_property(text_label, "modulate:a", 0.0, 0.8)
	await fourth_tween.finished
	text_label.text = "A spark becomes a flame. A flame becomes a world."
	var fifth_tween := create_tween()
	fifth_tween.tween_property(text_label, "modulate:a", 1.0, 1.2)
	await fifth_tween.finished
	await get_tree().create_timer(1.7).timeout

	var final_text_tween := create_tween()
	final_text_tween.tween_property(text_label, "modulate:a", 0.0, 0.8)
	await final_text_tween.finished
	text_label.text = "Oh! You're awake. That's... unexpected."

	var imp_portrait: TextureRect
	var imp_texture := load("res://Assets/UI/infernal_intern_face.svg") as Texture2D
	if imp_texture != null:
		imp_portrait = TextureRect.new()
		imp_portrait.texture = imp_texture
		imp_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		imp_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		imp_portrait.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		imp_portrait.position = Vector2(-90, -205)
		imp_portrait.size = Vector2(180, 140)
		imp_portrait.modulate.a = 0.0
		overlay.add_child(imp_portrait)
		var portrait_tween := create_tween()
		portrait_tween.tween_property(imp_portrait, "modulate:a", 1.0, 0.8)
		await portrait_tween.finished

	var imp_line_tween := create_tween()
	imp_line_tween.tween_property(text_label, "modulate:a", 1.0, 1.0)
	await imp_line_tween.finished
	await get_tree().create_timer(1.2).timeout

	# The imp leaves the scene so the newly forming realm gets the spotlight.
	var imp_departure_tween := create_tween()
	imp_departure_tween.set_parallel(true)
	imp_departure_tween.tween_property(text_label, "modulate:a", 0.0, 0.7)
	if imp_portrait != null:
		imp_departure_tween.tween_property(imp_portrait, "modulate:a", 0.0, 0.7)
	await imp_departure_tween.finished

	# Reveal the realm from a distant point and grow it into its normal scale.
	realm_view.pivot_offset = realm_view.size * 0.5
	realm_view.scale = Vector2(0.035, 0.035)
	realm_view.modulate.a = 0.0
	realm_view.show()
	var realm_reveal_tween := create_tween()
	realm_reveal_tween.set_parallel(true)
	realm_reveal_tween.tween_property(
		realm_view,
		"scale",
		Vector2.ONE,
		2.8
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	realm_reveal_tween.tween_property(
		realm_view,
		"modulate:a",
		1.0,
		2.2
	)
	await realm_reveal_tween.finished

	# Let the player take in the formed realm before the imp returns.
	await get_tree().create_timer(7.0).timeout

	text_label.text = "Here. A little Heat. Don't ask where I got it."
	var gift_tween := create_tween()
	gift_tween.set_parallel(true)
	gift_tween.tween_property(text_label, "modulate:a", 1.0, 0.9)
	if imp_portrait != null:
		gift_tween.tween_property(imp_portrait, "modulate:a", 1.0, 0.8)
	await gift_tween.finished
	await get_tree().create_timer(1.7).timeout

	var fade_tween := create_tween()
	fade_tween.tween_property(overlay, "modulate:a", 0.0, 2.0)
	await fade_tween.finished
	overlay.queue_free()

	realm_view.scale = Vector2.ONE
	realm_view.modulate = Color.WHITE
	realm_view.visible = true if realm_previous_visibility else false
	for child in previous_visibility:
		child.visible = previous_visibility[child]

	# Give exactly enough Heat for Atomic Friction's first purchase (15 Heat).
	state.set_resource_amount(ResourceIds.HEAT, INTRO_STARTING_HEAT)
	if save_manager != null and time_manager != null:
		save_manager.save_game(state, time_manager)
	is_new_save = false
	is_intro_playing = false


func _add_tutorial_archive_button() -> void:
	var options_content := $OptionsPanel/OptionsContent as VBoxContainer
	var archive_button := Button.new()
	archive_button.name = "TutorialArchiveButton"
	archive_button.text = "TUTORIAL ARCHIVE"
	archive_button.icon = load("res://Assets/UI/infernal_notes_book.svg") as Texture2D
	archive_button.custom_minimum_size = Vector2(0, 38)
	archive_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	archive_button.pressed.connect(_on_tutorial_archive_button_pressed)
	options_content.add_child(archive_button)


func _on_tutorial_archive_button_pressed() -> void:
	if tutorial_manager == null or assistant_popup == null:
		return
	assistant_popup.show_archive(tutorial_manager.get_archive_entries())


func _style_options_panel() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.045, 0.055, 0.97)
	panel_style.border_color = Color(0.42, 0.27, 0.22, 1.0)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left = 14.0
	panel_style.content_margin_right = 14.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_bottom = 12.0
	$OptionsPanel.add_theme_stylebox_override("panel", panel_style)

	for node_path in [
		"OptionsPanel/OptionsContent/SaveButton",
		"OptionsPanel/OptionsContent/OptionsCloseButton",
		"OptionsPanel/OptionsContent/QuitGameButton"
	]:
		var button := get_node(node_path) as Button
		button.add_theme_font_size_override("font_size", 10)
		button.add_theme_color_override("font_color", Color(1.0, 0.84, 0.68))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.82))
		button.add_theme_color_override("font_pressed_color", Color(1.0, 0.75, 0.48))
		button.add_theme_stylebox_override("normal", _create_options_button_style(
			Color(0.095, 0.065, 0.065, 1.0), Color(0.34, 0.23, 0.20, 1.0)
		))
		button.add_theme_stylebox_override("hover", _create_options_button_style(
			Color(0.17, 0.095, 0.07, 1.0), Color(0.78, 0.39, 0.20, 1.0)
		))
		button.add_theme_stylebox_override("pressed", _create_options_button_style(
			Color(0.24, 0.12, 0.075, 1.0), Color(0.95, 0.49, 0.22, 1.0)
		))
		button.add_theme_stylebox_override("disabled", _create_options_button_style(
			Color(0.075, 0.065, 0.07, 1.0), Color(0.22, 0.17, 0.16, 1.0)
		))

	for node_path in [
		"OptionsPanel/OptionsContent/UISoundsCheckBox",
		"OptionsPanel/OptionsContent/AmbientAudioCheckBox"
	]:
		var checkbox := get_node(node_path) as CheckBox
		checkbox.add_theme_font_size_override("font_size", 10)
		checkbox.add_theme_color_override("font_color", Color(0.88, 0.80, 0.75))
		checkbox.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.73))
		checkbox.add_theme_color_override("font_pressed_color", Color(1.0, 0.84, 0.65))
		checkbox.add_theme_color_override("font_disabled_color", Color(0.42, 0.38, 0.38))
		checkbox.add_theme_icon_override(
			"unchecked",
			load("res://Assets/UI/Options/checkbox_unchecked.svg") as Texture2D
		)
		checkbox.add_theme_icon_override(
			"checked",
			load("res://Assets/UI/Options/checkbox_checked.svg") as Texture2D
		)
		checkbox.add_theme_icon_override(
			"unchecked_disabled",
			load("res://Assets/UI/Options/checkbox_unchecked.svg") as Texture2D
		)
		checkbox.add_theme_icon_override(
			"checked_disabled",
			load("res://Assets/UI/Options/checkbox_checked.svg") as Texture2D
		)
		checkbox.add_theme_constant_override("h_separation", 7)

	$OptionsPanel/OptionsContent/VisualEffectsQualityLabel.add_theme_font_size_override(
		"font_size", 10
	)
	$OptionsPanel/OptionsContent/VisualEffectsQualityLabel.add_theme_color_override(
		"font_color", Color(1.0, 0.84, 0.68)
	)
	var quality_picker: OptionButton = $OptionsPanel/OptionsContent/VisualEffectsQualityOption
	quality_picker.add_theme_font_size_override("font_size", 10)
	quality_picker.add_theme_color_override("font_color", Color(0.88, 0.80, 0.75))
	quality_picker.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.73))
	quality_picker.add_theme_stylebox_override("normal", _create_options_button_style(
		Color(0.095, 0.065, 0.065, 1.0), Color(0.34, 0.23, 0.20, 1.0)
	))
	quality_picker.add_theme_stylebox_override("hover", _create_options_button_style(
		Color(0.17, 0.095, 0.07, 1.0), Color(0.78, 0.39, 0.20, 1.0)
	))

	$OptionsPanel/OptionsContent/MasterVolumeLabel.add_theme_font_size_override(
		"font_size", 10
	)
	$OptionsPanel/OptionsContent/MasterVolumeLabel.add_theme_color_override(
		"font_color", Color(1.0, 0.84, 0.68)
	)

	var slider_track := StyleBoxFlat.new()
	slider_track.bg_color = Color(0.13, 0.095, 0.09, 1.0)
	slider_track.border_color = Color(0.34, 0.23, 0.20, 1.0)
	slider_track.set_border_width_all(1)
	slider_track.set_corner_radius_all(3)
	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = Color(0.75, 0.32, 0.15, 1.0)
	slider_fill.set_corner_radius_all(3)
	$OptionsPanel/OptionsContent/MasterVolumeSlider.add_theme_stylebox_override(
		"slider", slider_track
	)
	$OptionsPanel/OptionsContent/MasterVolumeSlider.add_theme_stylebox_override(
		"grabber_area", slider_fill
	)
	$OptionsPanel/OptionsContent/MasterVolumeSlider.add_theme_stylebox_override(
		"grabber_area_highlight", slider_fill.duplicate()
	)


func _create_options_button_style(
	background_color: Color,
	border_color: Color
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


func _create_realm_view() -> void:
	space_background = TextureRect.new()
	space_background.name = "SpaceBackground"
	space_background.set_script(space_background_script)
	space_background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	space_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space_background.z_index = -20
	space_background.modulate = Color(1.0, 1.0, 1.0, 0.58)
	add_child(space_background)

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


func _on_generator_purchased() -> void:
	if tutorial_manager != null:
		tutorial_manager.notify_event("first_generator_purchase")


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
	generator_panel.generator_purchased.connect(
		_on_generator_purchased
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
	generator_panel.relics_changed.connect(_on_generator_relics_changed)
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
	# Start with no generator focused. The player chooses a machine
	# explicitly after starting, loading, or rebuilding a realm.
	_set_selected_generator("")


func _on_generator_panel_selection_requested(generator_id: String) -> void:
	if reliquary_window != null:
		reliquary_window.hide()
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
			_update_navigation_buttons("GeneratorsButton")
		else:
			# Clicking the focused generator in the list returns to its panel.
			generator_list_mode = false
			$NavigationTitlePanel/NavigationTitle.text = "GENERATOR"
			_refresh_generator_panel_visibility()
			_on_generator_upgrades_requested(generator_id)
		return

	# Choosing another generator from the list returns to focused mode.
	generator_list_mode = false
	_on_generator_selection_requested(generator_id)


func _on_generator_selection_requested(generator_id: String) -> void:
	# Empty-space clicks in RealmView clear focus without touching navigation.
	if generator_id == "":
		_deselect_generator()
		return

	# Clicking the already-focused machine should keep focus. Empty-space
	# clicks are the explicit way to dismiss the focused generator.
	if generator_id == selected_generator_id:
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
	# Generator focus is not a bottom-navigation destination.
	_update_navigation_buttons("")

	_set_selected_generator(generator_id)
	_on_generator_upgrades_requested(generator_id)


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
	var tree_assigned_upgrade_ids := _get_upgrade_tree_assigned_ids()

	for upgrade in state.upgrades.values():
		if not state.upgrade_system.is_upgrade_visible(upgrade):
			continue

		var upgrade_id: String = upgrade.definition.id
		var generator_id: String = upgrade.definition.generator_id

		# Keep global upgrades in the main panel as before. Generator-specific
		# upgrades only appear here when no upgrade tree has a node for them.
		if generator_id != "" and tree_assigned_upgrade_ids.has(upgrade_id):
			continue

		# Keep all generator unlocks together in the dedicated section,
		# regardless of whether the unlock is automatic or manually purchased.
		if _is_generator_unlock_for_main_panel(upgrade):
			add_automatic_upgrade_panel(upgrade)
			continue

		if upgrade.definition.automatic:
			automatic_upgrades.append(upgrade)
			continue

		add_upgrade_panel(upgrade)

	_create_initial_effects_ui(automatic_upgrades)


func _is_generator_unlock_for_main_panel(upgrade: Upgrade) -> bool:
	return _get_generator_id_for_unlock_upgrade(upgrade) != ""


func _get_generator_id_for_unlock_upgrade(upgrade: Upgrade) -> String:
	# Map progression unlock upgrades to the generator they introduce.
	# These stay in the main Upgrades grid even when their purchase is automatic.
	var unlock_generator_ids: Dictionary = {
		"molecular_agitation": "molecular_agitation",
		"matter_furnace_unlock": "matter_furnace",
		"lava_mite_colony_unlock": "lava_mite_colony",
		"unlock_infernal_condensation": "thermal_furnace",
		"thermal_compressor_unlock": "thermal_compressor",
		"infernal_forge_unlock": "infernal_forge"
	}
	return str(unlock_generator_ids.get(upgrade.definition.id, ""))


func _get_upgrade_tree_assigned_ids() -> Dictionary:
	var assigned_ids: Dictionary = {}
	var layouts: Array[GeneratorUpgradeLayout] = [
		AtomicFrictionUpgradeLayout.new(),
		MolecularAgitationUpgradeLayout.new(),
		ThermalFurnaceUpgradeLayout.new(),
		ThermalCompressorUpgradeLayout.new(),
		InfernalForgeUpgradeLayout.new(),
		LavaMiteUpgradeLayout.new(),
		MatterFurnaceUpgradeLayout.new()
	]

	for layout in layouts:
		for upgrade_id in layout.positions.keys():
			assigned_ids[upgrade_id] = true

	var eternal_layout := EternalFlameUpgradeLayout.new()
	for upgrade_id in eternal_layout.positions.keys():
		assigned_ids[upgrade_id] = true

	return assigned_ids


func _is_unassigned_generator_upgrade(upgrade: Upgrade) -> bool:
	if upgrade.definition.generator_id == "":
		return false

	return not _get_upgrade_tree_assigned_ids().has(
		upgrade.definition.id
	)



func add_upgrade_panel(
	upgrade: Upgrade
	) -> void:

	# Generator-specific upgrades belong in their tree when assigned.
	# Unassigned ones fall back to the main Upgrades panel as a safety net.
	if (
		upgrade.definition.generator_id != ""
		and not _is_unassigned_generator_upgrade(upgrade)
	):
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

	var effects_label := Label.new()
	effects_label.text = "Effects"
	effects_label.custom_minimum_size = Vector2(0, 35)
	effects_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	$UpgradeScroll/UpgradeContent/GeneralUpgradeContainer.add_child(effects_label)

	effects_flow = _create_automatic_upgrade_flow("EffectsFlow")


func _create_generator_unlocks_container() -> void:
	if generator_unlocks_flow != null:
		return

	var unlocks_label := Label.new()
	unlocks_label.text = "Generator Unlocks"
	unlocks_label.custom_minimum_size = Vector2(0, 35)
	unlocks_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	$UpgradeScroll/UpgradeContent/GeneralUpgradeContainer.add_child(unlocks_label)

	generator_unlocks_flow = _create_automatic_upgrade_flow("GeneratorUnlocksFlow")


func _create_automatic_upgrade_flow(flow_name: String) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.name = flow_name
	flow.custom_minimum_size = Vector2(0, 0)
	flow.add_theme_constant_override("h_separation", 3)
	flow.add_theme_constant_override("v_separation", 3)
	$UpgradeScroll/UpgradeContent/GeneralUpgradeContainer.add_child(flow)
	return flow



func add_automatic_upgrade_panel(
	upgrade: Upgrade
	) -> void:

	var is_generator_unlock := _is_generator_unlock_for_main_panel(upgrade)
	if not is_generator_unlock:
		if (
			upgrade.definition.generator_id != ""
			and not _is_unassigned_generator_upgrade(upgrade)
		):
			return

	if upgrade_panels.has(upgrade.definition.id):
		return

	if not state.upgrade_system.is_upgrade_visible(upgrade):
		return

	var target_flow: HFlowContainer
	if is_generator_unlock:
		_create_generator_unlocks_container()
		target_flow = generator_unlocks_flow
	else:
		_create_effects_container()
		target_flow = effects_flow

	var panel = upgrade_panel_scene.instantiate()
	panel.custom_minimum_size = Vector2(44, 44)
	panel.size = Vector2(44, 44)
	target_flow.add_child(panel)

	panel.setup(
		state,
		simulation,
		input_handler,
		upgrade.definition.id,
		$UpgradeInfoPopup
	)
	panel.purchase_succeeded.connect(_play_ui_purchase)

	upgrade_panels[upgrade.definition.id] = panel



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

	# Show the contextual tutorial for this newly unlocked generator.
	# TutorialManager queues it if another tutorial is already open.
	if tutorial_manager != null:
		tutorial_manager.notify_event("generator_unlocked:" + generator_id)

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

		if _is_generator_unlock_for_main_panel(upgrade):
			add_automatic_upgrade_panel(upgrade)
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
		
		if _is_generator_unlock_for_main_panel(upgrade):
			add_automatic_upgrade_panel(upgrade)
		elif upgrade.definition.automatic:
			add_automatic_upgrade_panel(upgrade)
		else:
			add_upgrade_panel(upgrade)

# ============================================================
# MAIN LOOP
# ============================================================

func _process(
	delta: float
	) -> void:

	if is_loading or is_intro_playing:
		return
	if state != null and state.prestige_planning:
		_update_navigation_title_visibility()
		_update_ambient_audio(delta)
		return

	time_manager.update(
		delta
	)
	if tutorial_manager != null and state.get_heat_leak_per_second() > 0.0:
		tutorial_manager.notify_event("heat_leak_started")
	if tutorial_manager != null and state.get_resource_amount(ResourceIds.CRYSTALLIZED_FLAME) > 0.0:
		tutorial_manager.notify_event("first_crystallized_flame")
	if (
		tutorial_manager != null
		and state.resource_statistics.get_total_produced(ResourceIds.ASH) >= 10.0
	):
		tutorial_manager.notify_event("first_ash")
	if (
		tutorial_manager != null
		and state.resource_statistics.get_total_produced(ResourceIds.MATTER) >= 10.0
	):
		tutorial_manager.notify_event("first_matter")
	if tutorial_manager != null and state.get_resource_amount(ResourceIds.ESSENCE) > 0.0:
		tutorial_manager.notify_event("first_essence")
	if tutorial_manager != null and state.get_matter_decay_per_second() > 0.0:
		tutorial_manager.notify_event("matter_decay_started")
	state.achievement_manager.update(state)
	if $AchievementPanel.visible:
		$AchievementPanel.refresh()

	_update_reliquary_navigation_visibility()
	_update_navigation_title_visibility()
	_update_ambient_audio(delta)


func _update_reliquary_navigation_visibility() -> void:
	var button := get_node_or_null("ReliquaryButton") as Button
	if button == null:
		return
	button.visible = (
		state != null
		and state.eternal_flame_upgrade_manager.is_reliquary_unlocked(state.eternal_flame_state)
	)


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
		or (reliquary_window != null and reliquary_window.visible)
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

	# The focused view contains at most one panel, so never show its
	# scrollbar. Switching modes explicitly also avoids a stale scrollbar
	# thumb lingering until the next scroll input.
	$GeneratorScroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
		if generator_list_mode
		else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	)

	# In focused mode, no selection means no generator panel at all.
	$GeneratorScroll.visible = generator_list_mode or selected_generator_id != ""

	if generator_list_mode and selected_panel != null:
		_scroll_generator_list_to_selected()
	elif not generator_list_mode:
		$GeneratorScroll.scroll_vertical = 0


func _scroll_generator_list_to_selected() -> void:
	# Wait for the list layout to update before scrolling; otherwise the
	# selected panel may still have its old focused-mode position.
	await get_tree().process_frame

	if not generator_list_mode or not $GeneratorScroll.visible:
		return

	var selected_panel := _get_generator_panel(selected_generator_id)
	if selected_panel != null:
		$GeneratorScroll.ensure_control_visible(selected_panel)


func _create_reliquary_window() -> void:
	if reliquary_window != null:
		return

	reliquary_window = PanelContainer.new()
	reliquary_window.name = "ReliquaryWindow"
	reliquary_window.visible = false
	reliquary_window.z_index = 50
	reliquary_window.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	reliquary_window.offset_left = 12.0
	reliquary_window.offset_top = 112.0
	reliquary_window.offset_right = 655.0
	reliquary_window.offset_bottom = 575.0
	add_child(reliquary_window)

	reliquary_panel = ReliquaryPanel.new()
	reliquary_panel.name = "ReliquaryInventory"
	reliquary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reliquary_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reliquary_window.add_child(reliquary_panel)
	reliquary_panel.setup(state)
	reliquary_panel.relics_changed.connect(_on_reliquary_relics_changed)


func _on_reliquary_relics_changed() -> void:
	if state == null:
		return
	state.rebuild_relic_modifiers()
	save_manager.save_game(state, time_manager)


func _on_generator_relics_changed() -> void:
	if state == null:
		return
	state.rebuild_relic_modifiers()
	if reliquary_panel != null:
		reliquary_panel.refresh()
	save_manager.save_game(state, time_manager)


func _on_reliquary_button_pressed() -> void:
	if state == null or reliquary_window == null:
		return
	if not state.eternal_flame_upgrade_manager.is_reliquary_unlocked(state.eternal_flame_state):
		return

	_clear_generator_focus()
	generator_list_mode = false
	$ResourcePanel.hide()
	$GeneratorScroll.hide()
	$UpgradeScroll.hide()
	$StatsPanel.hide()
	$OptionsPanel.hide()
	$AchievementPanel.hide()
	$PrestigePanel.hide()
	if realm_view != null:
		realm_view.hide()
	reliquary_window.show()
	reliquary_panel.refresh()
	$NavigationTitlePanel/NavigationTitle.text = "RELIQUARY"
	_update_navigation_buttons("ReliquaryButton")


func _update_navigation_buttons(active_button_name: String = "GeneratorsButton") -> void:
	var navigation: Array[Dictionary] = [
		{"name": "GeneratorsButton", "label": "GENERATORS", "icon_path": "res://Assets/UI/Navigation/generators.svg"},
		{"name": "UpgradesButton", "label": "UPGRADES", "icon_path": "res://Assets/UI/Navigation/upgrades.svg"},
		{"name": "StatsButton", "label": "STATS", "icon_path": "res://Assets/UI/Navigation/stats.svg"},
		{"name": "PrestigeButton", "label": "REALM", "icon_path": "res://Assets/UI/Navigation/realm.svg"},
		{"name": "ReliquaryButton", "label": "RELIQUARY", "icon_path": "res://Assets/UI/Navigation/realm.svg"},
		{"name": "AchievementButton", "label": "ACHIEVEMENTS", "icon_path": "res://Assets/UI/Navigation/achievements.svg"},
		{"name": "OptionsButton", "label": "OPTIONS", "icon_path": "res://Assets/UI/Navigation/options.svg"},
	]
	for entry in navigation:
		var button := get_node_or_null(str(entry.name)) as Button
		if button == null:
			continue
		if str(entry.name) == "ReliquaryButton":
			button.visible = (
				state != null
				and state.eternal_flame_upgrade_manager.is_reliquary_unlocked(state.eternal_flame_state)
			)
		button.text = str(entry.label)
		button.icon = load(str(entry.icon_path)) as Texture2D
		button.expand_icon = false
		button.add_theme_font_size_override(
			"font_size", 8 if str(entry.name) in ["GeneratorsButton", "AchievementButton"] else 9
		)
		var is_active: bool = str(entry.name) == active_button_name
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.19, 0.105, 0.075, 1.0) if is_active else Color(0.075, 0.06, 0.075, 0.98)
		normal.border_color = Color(0.95, 0.48, 0.20, 1.0) if is_active else Color(0.28, 0.20, 0.19, 1.0)
		normal.set_border_width_all(2 if is_active else 1)
		normal.set_corner_radius_all(4)
		normal.content_margin_left = 5.0
		normal.content_margin_right = 5.0
		normal.content_margin_top = 4.0
		normal.content_margin_bottom = 4.0
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_color_override("font_color", Color(1.0, 0.84, 0.65) if is_active else Color(0.86, 0.78, 0.73))
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.24, 0.13, 0.09, 1.0) if is_active else Color(0.14, 0.09, 0.085, 1.0)
		hover.border_color = Color(1.0, 0.59, 0.29, 1.0) if is_active else Color(0.55, 0.32, 0.23, 1.0)
		button.add_theme_stylebox_override("hover", hover)
		var pressed := normal.duplicate() as StyleBoxFlat
		pressed.bg_color = Color(0.28, 0.14, 0.095, 1.0)
		pressed.border_color = Color(0.85, 0.43, 0.20, 1.0)
		button.add_theme_stylebox_override("pressed", pressed)


func _on_generators_button_pressed() -> void:
	if reliquary_window != null:
		reliquary_window.hide()
	$NavigationTitlePanel/NavigationTitle.text = "GENERATORS"
	generator_list_mode = not generator_list_mode
	if generator_list_mode and tutorial_manager != null:
		tutorial_manager.notify_event("navigation_generators")

	# Keep the current selection when opening the list so it can be brought
	# into view. The same selection is focused again when the list is closed.
	selected_upgrade_generator_id = ""
	if generator_upgrade_tree != null:
		generator_upgrade_tree.hide()

	$OptionsPanel.hide()
	$StatsPanel.hide()
	$UpgradeScroll.hide()
	$PrestigePanel.hide()
	$AchievementPanel.hide()
	_refresh_generator_panel_visibility()

	$GeneratorsButton.text = "GENERATORS"
	_update_navigation_buttons("GeneratorsButton")


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
	if reliquary_window != null:
		reliquary_window.hide()
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
		if tutorial_manager != null:
			tutorial_manager.notify_event("navigation_achievements")
	else:
		$GeneratorScroll.show()
		_refresh_generator_panel_visibility()
	_update_navigation_buttons("AchievementButton" if should_open else "GeneratorsButton")


func _on_options_button_pressed() -> void:
	if reliquary_window != null:
		reliquary_window.hide()
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
	_update_navigation_buttons("OptionsButton" if should_open else "GeneratorsButton")


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


func _on_visual_effect_quality_selected(index: int) -> void:
	visual_effect_quality = clampi(index, VISUAL_EFFECT_OFF, VISUAL_EFFECT_HIGH)
	_save_visual_settings()

	if realm_view != null:
		realm_view.set_visual_effect_quality(visual_effect_quality)


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
		var legacy_effects_enabled: bool = bool(config.get_value(
			"graphics",
			"animated_visual_effects",
			true
		))
		visual_effect_quality = clampi(
			int(config.get_value(
				"graphics",
				"visual_effect_quality",
				VISUAL_EFFECT_MEDIUM if legacy_effects_enabled else VISUAL_EFFECT_OFF
			)),
			VISUAL_EFFECT_OFF,
			VISUAL_EFFECT_HIGH
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
		"visual_effect_quality",
		visual_effect_quality
	)
	# Keep the old key for compatibility with builds that still use the toggle.
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
	if reliquary_window != null:
		reliquary_window.hide()
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
		if tutorial_manager != null:
			tutorial_manager.notify_event("navigation_stats")

	_update_navigation_buttons("StatsButton" if should_open else "GeneratorsButton")


func _on_upgrades_button_pressed() -> void:
	if reliquary_window != null:
		reliquary_window.hide()
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
		_update_navigation_buttons("GeneratorsButton")
		return

	if tutorial_manager != null:
		tutorial_manager.notify_event("navigation_upgrades")
	$UpgradeScroll.show()
	$UpgradeScroll.offset_left = 12.0
	$UpgradeScroll.offset_top = 112.0
	$UpgradeScroll.offset_right = 655.0
	_update_upgrade_view()
	_update_navigation_buttons("UpgradesButton")

func _on_prestige_requested() -> void:
	if tutorial_manager != null and not tutorial_manager.has_completed_tutorial("first_realm_smash"):
		$PrestigePanel.smash_button.disabled = false
		tutorial_manager.notify_event("first_realm_smash")
		return
	$StatsPanel.hide()
	$UpgradeScroll.hide()
	if generator_upgrade_tree != null:
		generator_upgrade_tree.hide()
	$GeneratorScroll.hide()
	$PrestigePanel.hide()

	prestige_animation.play()


func _on_prestige_destruction_complete() -> void:
	$PrestigePanel.perform_smash()
	
func _enter_prestige_planning_mode() -> void:
	if state == null or not state.prestige_planning:
		return
	if prestige_animation != null and prestige_animation.is_playing:
		prestige_animation.finish_in_void()
	if realm_view != null:
		realm_view.hide()
	$ResourcePanel.hide()
	$GeneratorScroll.hide()
	$UpgradeScroll.hide()
	$StatsPanel.hide()
	$OptionsPanel.hide()
	$AchievementPanel.hide()
	$PrestigePanel.show()
	generator_list_mode = false
	selected_upgrade_generator_id = ""
	$NavigationTitlePanel/NavigationTitle.text = "REALM"
	_update_navigation_buttons("PrestigeButton")
	for button_name in ["GeneratorsButton", "UpgradesButton", "StatsButton", "AchievementButton", "OptionsButton"]:
		var button := get_node_or_null(button_name) as Button
		if button != null:
			button.disabled = true


func _on_prestige_button_pressed() -> void:
	if reliquary_window != null:
		reliquary_window.hide()
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
		if tutorial_manager != null:
			tutorial_manager.notify_event("navigation_realm")
	_update_navigation_buttons("PrestigeButton" if should_open else "GeneratorsButton")


func _on_run_reset() -> void:
	if reliquary_window != null:
		reliquary_window.hide()
	generator_list_mode = false
	_clear_generator_focus()
	$GeneratorsButton.text = "GENERATORS"

	# ------------------------------------------------------------
	# Rebuild the physical realm
	# ------------------------------------------------------------

	if space_background != null:
		space_background.call("choose_random_background")
	if realm_view != null:
		realm_view.rebuild_realm(
			state.realm_layout
		)
		realm_view.show()
	# Resume the rebirth animation only after the player commits to
	# starting the next realm, not while they are in the Flame Shop.
	if prestige_animation != null:
		prestige_animation.play_rebirth()
	$ResourcePanel.show()
	$PrestigePanel.hide()
	for button_name in ["GeneratorsButton", "UpgradesButton", "StatsButton", "AchievementButton", "OptionsButton"]:
		var button := get_node_or_null(button_name) as Button
		if button != null:
			button.disabled = false
	$NavigationTitlePanel/NavigationTitle.text = "GENERATORS"
	_update_navigation_buttons("GeneratorsButton")
	$GeneratorScroll.show()

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
	generator_unlocks_flow = null
	
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

		ResourceIds.CRYSTALLIZED_FLAME:
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
		ResourceIds.CRYSTALLIZED_FLAME
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
			"[img=14x14]%s[/img] [b]%s:[/b]" % [
				ResourceIconRegistry.get_icon_path(resource_id),
				_get_resource_display_name(resource_id)
			]
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
			"[img=14x14]%s[/img] Heat Overflow: %s" % [
				ResourceIconRegistry.get_icon_path(ResourceIds.HEAT),
				_format_resource_amount(overflow)
			]
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
