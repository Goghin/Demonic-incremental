
extends Control

var is_loading: bool = true
var state: GameState
var simulation: Simulation
var time_manager: TimeManager
var input_handler: InputHandler
var save_manager: SaveManager

var generator_panel_scene = preload("res://UI/generator_panel.tscn")
@onready var loading_screen: Control = $LoadingScreen

func _ready() -> void:
	loading_screen.set_status("Awakening the realm...")
	loading_screen.set_progress(0.0)

	await get_tree().process_frame

	state = GameState.new()

	loading_screen.set_status("Initializing the simulation...")
	loading_screen.set_progress(0.15)

	await get_tree().process_frame

	simulation = Simulation.new(state)

	loading_screen.set_status("Preparing the flow of time...")
	loading_screen.set_progress(0.25)

	await get_tree().process_frame

	time_manager = TimeManager.new(simulation)

	loading_screen.set_status("Preparing controls...")
	loading_screen.set_progress(0.35)

	await get_tree().process_frame

	save_manager = SaveManager.new()
	input_handler = InputHandler.new(simulation)

	loading_screen.set_status("Restoring your dominion...")
	loading_screen.set_progress(0.45)

	await get_tree().process_frame

	var loaded = save_manager.load_game(
		state,
		time_manager
	)

	if loaded:
		simulation.rebuild_upgrade_effects()

		loading_screen.set_status("Simulating time lost to the void...")
		loading_screen.set_progress(0.55)

		await get_tree().process_frame

		var offline_seconds = time_manager.process_offline_time()

		print(
			"Offline time simulated: ",
			offline_seconds,
			" seconds"
		)

		if offline_seconds > 0.0:
			save_manager.save_game(
				state,
				time_manager
			)

	loading_screen.set_status("Preparing resources...")
	loading_screen.set_progress(0.65)

	await get_tree().process_frame

	$ResourcePanel.setup(state)

	$StatsPanel.setup(
		state,
		time_manager
	)
	$PrestigePanel.setup(
	state,
	save_manager,
	time_manager
	)
	var upgrade_info_popup = $UpgradeInfoPopup

	print(
		"Timestamp: ",
		time_manager.last_real_timestamp
	)

	print(
		"Offline seconds: ",
		time_manager.get_offline_seconds()
	)

	loading_screen.set_status("Awakening generators...")
	loading_screen.set_progress(0.75)

	await get_tree().process_frame

	for generator in state.generators.values():
		var panel = generator_panel_scene.instantiate()

		$GeneratorScroll/GeneratorContainer.add_child(
			panel
		)

		panel.setup(
			state,
			input_handler,
			generator.definition.id
		)

	loading_screen.set_status("Rebuilding upgrades...")
	loading_screen.set_progress(0.85)

	await get_tree().process_frame

	var upgrade_panel_scene = preload(
		"res://UI/upgrade_panel.tscn"
	)

	var upgrade_groups: Dictionary = {}
	var automatic_upgrades: Array = []

	for upgrade in state.upgrades.values():
		if upgrade.definition.automatic:
			automatic_upgrades.append(
				upgrade
			)
			continue

		var group_id = (
			upgrade.definition.upgrade_group_id
		)

		if not upgrade_groups.has(group_id):
			upgrade_groups[group_id] = []

		upgrade_groups[group_id].append(
			upgrade
		)

	var upgrades_label = Label.new()

	upgrades_label.text = "UPGRADES"

	upgrades_label.custom_minimum_size = Vector2(
		0,
		35
	)

	upgrades_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	$UpgradeScroll/UpgradeContainer.add_child(
		upgrades_label
	)

	for group_id in upgrade_groups:
		var group_container = VBoxContainer.new()

		group_container.name = (
			"UpgradeGroup_%s" % group_id
		)

		group_container.add_theme_constant_override(
			"separation",
			6
		)

		$UpgradeScroll/UpgradeContainer.add_child(
			group_container
		)

		var group_label = Label.new()

		var group = state.get_upgrade_group(
			group_id
		)

		if group != null:
			group_label.text = group.display_name
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

		for upgrade in upgrade_groups[group_id]:
			var panel = upgrade_panel_scene.instantiate()

			panel.custom_minimum_size = Vector2(
				65,
				65
			)

			upgrade_flow.add_child(
				panel
			)

			panel.setup(
				state,
				simulation,
				input_handler,
				upgrade.definition.id,
				upgrade_info_popup
			)

	if not automatic_upgrades.is_empty():
		var effects_label = Label.new()

		effects_label.text = "EFFECTS"

		effects_label.custom_minimum_size = Vector2(
			0,
			35
		)

		effects_label.vertical_alignment = (
			VERTICAL_ALIGNMENT_CENTER
		)

		$UpgradeScroll/UpgradeContainer.add_child(
			effects_label
		)

		var effects_flow = HFlowContainer.new()

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

		$UpgradeScroll/UpgradeContainer.add_child(
			effects_flow
		)

		for upgrade in automatic_upgrades:
			var panel = upgrade_panel_scene.instantiate()

			panel.custom_minimum_size = Vector2(
				70,
				70
			)

			effects_flow.add_child(
				panel
			)

			panel.setup(
				state,
				simulation,
				input_handler,
				upgrade.definition.id,
				upgrade_info_popup
			)

	loading_screen.set_status("Realm awakened.")
	loading_screen.set_progress(1.0)

	await get_tree().process_frame

	is_loading = false
	loading_screen.visible = false

func _process(delta: float) -> void:
	if is_loading:
		return

	time_manager.update(delta)

func _on_rub_button_pressed() -> void:
	input_handler.rub()
	
	print(
		"Offline seconds: ",
		time_manager.get_offline_seconds()
	)
	
	save_manager.save_game(
		state,
		time_manager
	)


func _on_stats_button_pressed() -> void:
	$StatsPanel.visible = not $StatsPanel.visible
	
	if $StatsPanel.visible:
		$UpgradeScroll.visible = false
		$PrestigePanel.visible = false


func _on_upgrades_button_pressed() -> void:
	$UpgradeScroll.visible = not $UpgradeScroll.visible
	
	if $UpgradeScroll.visible:
		$StatsPanel.visible = false
		$PrestigePanel.visible = false
		
func _on_prestige_button_pressed() -> void:
	$PrestigePanel.visible = not $PrestigePanel.visible
	
	if $PrestigePanel.visible:
		$StatsPanel.visible = false
		$UpgradeScroll.visible = false
