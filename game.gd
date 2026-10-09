
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

	if not $UpgradeScroll.visible:
		$UpgradeScroll.visible = true
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

	if amount >= 1000000000.0:
		return "%.2fB" % (
			amount / 1000000000.0
		)

	if amount >= 1000000.0:
		return "%.2fM" % (
			amount / 1000000.0
		)

	if amount >= 1000.0:
		return "%.2fK" % (
			amount / 1000.0
		)

	if amount >= 1.0:
		return "%.2f" % amount

	return "%.3f" % amount
	
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
