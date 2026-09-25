
extends Control


var is_loading: bool = true

var state: GameState
var simulation: Simulation
var time_manager: TimeManager
var input_handler: InputHandler
var save_manager: SaveManager

var upgrade_group_containers: Dictionary = {}
var upgrade_flows: Dictionary = {}
var upgrade_panels: Dictionary = {}

var effects_flow: HFlowContainer

var generator_panel_scene = preload(
	"res://UI/generator_panel.tscn"
)

var upgrade_panel_scene = preload(
	"res://UI/upgrade_panel.tscn"
)

@onready var loading_screen: Control = $LoadingScreen


func _ready() -> void:
	loading_screen.set_status(
		"Awakening the realm..."
	)
	loading_screen.set_progress(
		0.0
	)

	await get_tree().process_frame

	state = GameState.new()

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

	if loaded:
		simulation.rebuild_upgrade_effects()

		loading_screen.set_status(
			"Simulating time lost to the void..."
		)
		loading_screen.set_progress(
			0.55
		)

		await get_tree().process_frame

		var offline_seconds = (
			time_manager.process_offline_time()
		)

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
# UPGRADE VISIBILITY
# ============================================================

func is_upgrade_visible(
	upgrade: Upgrade
	) -> bool:

	var definition = upgrade.definition
	
	# Eternal Flame technology requirement.
	if definition.technology_id != "":
		if not state.eternal_flame_state.is_technology_unlocked(
			definition.technology_id
		):
			return false
	
	# No generator association means this is a global upgrade.
	if definition.generator_id == "":
		return true
	
	var generator = state.get_generator(
		definition.generator_id
	)
	
	if generator == null:
		return false
	
	return generator.unlocked

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

	$UpgradeScroll/UpgradeContainer.add_child(
		upgrades_label
	)

	var automatic_upgrades: Array = []

	for upgrade in state.upgrades.values():
		if not is_upgrade_visible(
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

	if upgrade_panels.has(
		upgrade.definition.id
	):
		return

	if not is_upgrade_visible(
		upgrade
	):
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
		$UpgradeInfoPopup
	)

	upgrade_panels[
		upgrade.definition.id
	] = panel


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

	$UpgradeScroll/UpgradeContainer.add_child(
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

	$UpgradeScroll/UpgradeContainer.add_child(
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

	$UpgradeScroll/UpgradeContainer.add_child(
		effects_flow
	)


func add_automatic_upgrade_panel(
	upgrade: Upgrade
	) -> void:

	if upgrade_panels.has(
		upgrade.definition.id
	):
		return

	if not is_upgrade_visible(
		upgrade
	):
		return

	_create_effects_container()

	var panel = (
		upgrade_panel_scene.instantiate()
	)

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
		$UpgradeInfoPopup
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

	# Add the newly unlocked generator.
	_create_generator_panel(
		generator_id
	)

	# Add all upgrades that become visible because
	# this generator is now unlocked.
	for upgrade in state.upgrades.values():
		if not is_upgrade_visible(
			upgrade
		):
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
		if not is_upgrade_visible(
			upgrade
		):
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


# ============================================================
# BUTTONS
# ============================================================

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
