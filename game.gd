
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

var upgrade_group_containers: Dictionary = {}
var upgrade_flows: Dictionary = {}
var upgrade_panels: Dictionary = {}

var selected_upgrade_generator_id: String = ""

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

		var offline_seconds = await time_manager.process_offline_time()

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



# ============================================================
# UPGRADE UI
# ============================================================

func _create_initial_upgrade_ui() -> void:
	var upgrades_label = Label.new()

	upgrades_label.text = "UPGRADES"

	upgrades_label.custom_minimum_size = Vector2(
		0,
		35
	)

	upgrades_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	$UpgradeScroll/UpgradeContent/GeneralUpgradeContainer.add_child(
		upgrades_label
	)

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

	panel.custom_minimum_size = Vector2(
		70,
		70
	)

	panel.size = Vector2(
		70,
		70
	)

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
		return

	general_container.visible = false
	generator_container.visible = true

	if generator_upgrade_tree != null:
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
		2
	)

	upgrade_flow.add_theme_constant_override(
		"v_separation",
		2
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
		4
	)

	effects_flow.add_theme_constant_override(
		"v_separation",
		4
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

	panel.custom_minimum_size = Vector2(
		70,
		70
	)

	panel.size = Vector2(
		70,
		70
	)

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

	# Add the newly unlocked generator.
	_create_generator_panel(
		generator_id
	)

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
	_update_ambient_audio(delta)


# ============================================================
# BUTTONS
# ============================================================

func _on_options_button_pressed() -> void:
	var should_open: bool = not $OptionsPanel.visible

	$OptionsPanel.visible = should_open

	if should_open:
		$StatsPanel.hide()
		$UpgradeScroll.hide()
		$PrestigePanel.hide()


func _on_options_close_button_pressed() -> void:
	$OptionsPanel.hide()


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

	$StatsPanel.visible = not $StatsPanel.visible

	if $StatsPanel.visible:
		$OptionsPanel.hide()
		$UpgradeScroll.visible = false
		$PrestigePanel.visible = false



func _on_upgrades_button_pressed() -> void:

	if not $UpgradeScroll.visible:
		$UpgradeScroll.visible = true
		$OptionsPanel.hide()
		$StatsPanel.visible = false
		$PrestigePanel.visible = false

		selected_upgrade_generator_id = ""

		_update_upgrade_view()

		return

	# Upgrade panel is already open.

	if selected_upgrade_generator_id == "":
		$UpgradeScroll.visible = false

		return

	# A generator upgrade tree is open.
	# Switch back to the general upgrade panel.

	selected_upgrade_generator_id = ""

	_update_upgrade_view()

func _on_prestige_requested() -> void:
	$StatsPanel.hide()
	$UpgradeScroll.hide()
	$GeneratorScroll.hide()
	$PrestigePanel.hide()

	prestige_animation.play()


func _on_prestige_destruction_complete() -> void:
	$PrestigePanel.perform_smash()

	$GeneratorScroll.show()
	$PrestigePanel.show()
	
func _on_prestige_button_pressed() -> void:

	$PrestigePanel.visible = not $PrestigePanel.visible

	if $PrestigePanel.visible:
		$OptionsPanel.hide()
		$StatsPanel.visible = false
		$UpgradeScroll.visible = false


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
	$StatsPanel.visible = false
	$PrestigePanel.visible = false

	# If the requested generator tree is already open,
	# close the upgrade panel.
	if (
		$UpgradeScroll.visible
		and selected_upgrade_generator_id == generator_id
	):
		$UpgradeScroll.visible = false
		selected_upgrade_generator_id = ""

		return

	# Otherwise open/switch to this generator's tree.
	$UpgradeScroll.visible = true
	selected_upgrade_generator_id = generator_id

	_update_upgrade_view()

func _create_generator_upgrade_tree() -> void:

	if generator_upgrade_tree != null:
		return

	generator_upgrade_tree = (
		generator_upgrade_tree_scene.instantiate()
	)

	$UpgradeScroll/UpgradeContent/GeneratorUpgradeContainer.add_child(
		generator_upgrade_tree
	)
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

	var total_minutes := int(seconds / 60.0)
	var minutes := total_minutes % 60
	var hours := int(total_minutes / 60)

	if hours > 0:
		return "%dh %02dm" % [
			hours,
			minutes
		]

	return "%dm" % minutes
