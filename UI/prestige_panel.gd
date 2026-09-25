
class_name PrestigePanel
extends Control


signal technology_unlocked(technology_id: String)
signal run_reset

var state: GameState
var prestige_system: PrestigeSystem
var save_manager: SaveManager
var time_manager: TimeManager


# ----------------------------------------------------------------
# Main UI
# ----------------------------------------------------------------

var content_container: VBoxContainer

var tab_container: HBoxContainer
var distribution_button: Button
var shop_button: Button

var distribution_panel: VBoxContainer
var shop_panel: VBoxContainer


# ----------------------------------------------------------------
# Realm / Flame Distribution
# ----------------------------------------------------------------

var realm_container: VBoxContainer
var realm_available_label: Label
var realm_assigned_label: Label
var stabilize_button: Button

var realm_rows: Dictionary = {}


# ----------------------------------------------------------------
# Eternal Flame Shop
# ----------------------------------------------------------------

var eternal_flame_shop_scroll: ScrollContainer
var eternal_flame_upgrade_container: VBoxContainer
var eternal_flame_upgrade_rows: Dictionary = {}


const ETERNAL_FLAME_UPGRADE_IDS: Array[String] = [
	"eternal_furnace",
	"realm_attunement",
	"infernal_foundation",
	"essence_extraction"
]


# ----------------------------------------------------------------
# Existing Prestige UI
# ----------------------------------------------------------------

@onready var crystallized_flame_label: Label = (
	$VBoxContainer/CrystallizedFlameLabel
)

@onready var eternal_flame_label: Label = (
	$VBoxContainer/EternalFlameLabel
)

@onready var gain_label: Label = (
	$VBoxContainer/GainLabel
)

@onready var smash_button: Button = (
	$VBoxContainer/SmashButton
)


# ----------------------------------------------------------------
# Setup
# ----------------------------------------------------------------

func setup(
	game_state: GameState,
	game_save_manager: SaveManager,
	game_time_manager: TimeManager
	) -> void:
	
	state = game_state
	save_manager = game_save_manager
	time_manager = game_time_manager
	prestige_system = PrestigeSystem.new()
	
	_create_main_ui()
	_create_distribution_ui()
	_create_shop_ui()
	
	_show_distribution_panel()
	
	refresh()


# ----------------------------------------------------------------
# Main UI Structure
# ----------------------------------------------------------------

func _create_main_ui() -> void:
	if content_container != null:
		return
	
	content_container = VBoxContainer.new()
	content_container.name = "PrestigeContentContainer"
	
	content_container.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	
	content_container.add_theme_constant_override(
		"separation",
		8
	)
	
	$VBoxContainer.add_child(
		content_container
	)
	
	_create_tab_ui()


func _create_tab_ui() -> void:
	if tab_container != null:
		return
	
	tab_container = HBoxContainer.new()
	tab_container.name = "PrestigeTabContainer"
	
	tab_container.add_theme_constant_override(
		"separation",
		6
	)
	
	content_container.add_child(
		tab_container
	)
	
	distribution_button = Button.new()
	distribution_button.name = "FlameDistributionButton"
	distribution_button.text = "FLAME DISTRIBUTION"
	distribution_button.custom_minimum_size = Vector2(0, 40)
	
	distribution_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	
	tab_container.add_child(
		distribution_button
	)
	
	distribution_button.pressed.connect(
		_show_distribution_panel
	)
	
	shop_button = Button.new()
	shop_button.name = "EternalFlameShopButton"
	shop_button.text = "ETERNAL FLAME SHOP"
	shop_button.custom_minimum_size = Vector2(0, 40)
	
	shop_button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	
	tab_container.add_child(
		shop_button
	)
	
	shop_button.pressed.connect(
		_show_shop_panel
	)


# ----------------------------------------------------------------
# Distribution Panel
# ----------------------------------------------------------------

func _create_distribution_ui() -> void:
	if distribution_panel != null:
		return
	
	distribution_panel = VBoxContainer.new()
	distribution_panel.name = "FlameDistributionPanel"
	
	distribution_panel.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	
	distribution_panel.add_theme_constant_override(
		"separation",
		6
	)
	
	content_container.add_child(
		distribution_panel
	)
	
	_create_realm_ui()


func _create_realm_ui() -> void:
	if realm_container != null:
		return
	
	realm_container = VBoxContainer.new()
	realm_container.name = "RealmContainer"
	
	realm_container.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	
	realm_container.add_theme_constant_override(
		"separation",
		6
	)
	
	distribution_panel.add_child(
		realm_container
	)
	
	var title = Label.new()
	title.text = "REALM"
	title.custom_minimum_size = Vector2(0, 30)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	realm_container.add_child(title)
	
	realm_available_label = Label.new()
	realm_container.add_child(
		realm_available_label
	)
	
	realm_assigned_label = Label.new()
	realm_container.add_child(
		realm_assigned_label
	)
	
	stabilize_button = Button.new()
	stabilize_button.name = "StabilizeRealmButton"
	stabilize_button.text = "STABILIZE REALM"
	stabilize_button.custom_minimum_size = Vector2(0, 40)
	
	stabilize_button.pressed.connect(
		_on_stabilize_realm_pressed
	)
	
	realm_container.add_child(
		stabilize_button
	)
	
	_create_realm_stat_row(
		"stability",
		"Stability"
	)
	
	_create_realm_stat_row(
		"density",
		"Density"
	)
	
	_create_realm_stat_row(
		"integrity",
		"Integrity"
	)
	
	_create_realm_stat_row(
		"intensity",
		"Intensity"
	)
	
	_create_realm_stat_row(
		"resonance",
		"Resonance"
	)



func _create_realm_stat_row(
	stat_name: String,
	display_name: String
	) -> void:
	
	var row = VBoxContainer.new()
	row.name = "%sRow" % stat_name
	
	row.add_theme_constant_override(
		"separation",
		2
	)
	
	realm_container.add_child(
		row
	)
	
	var assignment_row = HBoxContainer.new()
	assignment_row.add_theme_constant_override(
		"separation",
		6
	)
	
	row.add_child(
		assignment_row
	)
	
	var label = Label.new()
	label.text = display_name
	label.custom_minimum_size = Vector2(100, 0)
	
	assignment_row.add_child(label)
	
	var minus_button = Button.new()
	minus_button.text = "-"
	minus_button.custom_minimum_size = Vector2(35, 30)
	
	assignment_row.add_child(minus_button)
	
	var value_label = Label.new()
	value_label.text = "0"
	value_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	value_label.custom_minimum_size = Vector2(40, 30)
	
	assignment_row.add_child(value_label)
	
	var plus_button = Button.new()
	plus_button.text = "+"
	plus_button.custom_minimum_size = Vector2(35, 30)
	
	assignment_row.add_child(plus_button)
	
	var effect_label = Label.new()
	effect_label.text = ""
	effect_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	effect_label.modulate = Color(0.7, 0.7, 0.7)
	
	row.add_child(
		effect_label
	)
	
	minus_button.pressed.connect(
		func():
			_on_realm_minus_pressed(stat_name)
	)
	
	plus_button.pressed.connect(
		func():
			_on_realm_plus_pressed(stat_name)
	)
	
	realm_rows[stat_name] = {
		"value_label": value_label,
		"minus_button": minus_button,
		"plus_button": plus_button,
		"effect_label": effect_label
	}


# ----------------------------------------------------------------
# Shop Panel
# ----------------------------------------------------------------

func _create_shop_ui() -> void:
	if shop_panel != null:
		return
	
	shop_panel = VBoxContainer.new()
	shop_panel.name = "EternalFlameShopPanel"
	
	shop_panel.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	
	shop_panel.add_theme_constant_override(
		"separation",
		6
	)
	
	content_container.add_child(
		shop_panel
	)
	
	var title = Label.new()
	title.text = "ETERNAL FLAME SHOP"
	title.custom_minimum_size = Vector2(0, 30)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	shop_panel.add_child(title)
	
	eternal_flame_shop_scroll = ScrollContainer.new()
	eternal_flame_shop_scroll.name = "EternalFlameShopScroll"

	eternal_flame_shop_scroll.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	eternal_flame_shop_scroll.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	eternal_flame_shop_scroll.custom_minimum_size = Vector2(0, 100)

	eternal_flame_shop_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)

	shop_panel.add_child(
		eternal_flame_shop_scroll
	)
	
	eternal_flame_upgrade_container = VBoxContainer.new()
	eternal_flame_upgrade_container.name = (
		"EternalFlameUpgradeContainer"
	)

	eternal_flame_upgrade_container.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	eternal_flame_upgrade_container.size_flags_vertical = (
		Control.SIZE_SHRINK_BEGIN
	)

	eternal_flame_upgrade_container.add_theme_constant_override(
		"separation",
		8
	)

	eternal_flame_shop_scroll.add_child(
		eternal_flame_upgrade_container
	)
	
	for upgrade_id in ETERNAL_FLAME_UPGRADE_IDS:
		_create_eternal_flame_upgrade_row(
			upgrade_id
		)
	print(
	"Eternal Flame shop rows: ",
	eternal_flame_upgrade_container.get_child_count()
	)

func _create_eternal_flame_upgrade_row(
	upgrade_id: String
	) -> void:
	
	var upgrade = (
		state.eternal_flame_upgrade_manager.get_upgrade(
			upgrade_id
		)
	)
	
	if upgrade == null:
		return
	
	var row = VBoxContainer.new()
	row.name = "%sRow" % upgrade_id
	
	row.add_theme_constant_override(
		"separation",
		2
	)
	
	eternal_flame_upgrade_container.add_child(
		row
	)
	
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override(
		"separation",
		6
	)
	
	row.add_child(top_row)
	
	var name_label = Label.new()
	name_label.text = upgrade.display_name
	name_label.custom_minimum_size = Vector2(150, 0)
	
	name_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	
	top_row.add_child(name_label)
	
	var level_label = Label.new()
	level_label.custom_minimum_size = Vector2(80, 0)
	level_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	
	top_row.add_child(level_label)
	
	var cost_label = Label.new()
	cost_label.custom_minimum_size = Vector2(100, 0)
	cost_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	
	top_row.add_child(cost_label)
	
	var purchase_button = Button.new()
	purchase_button.text = "BUY"
	purchase_button.custom_minimum_size = Vector2(70, 30)
	
	top_row.add_child(purchase_button)
	
	var description_label = Label.new()
	description_label.text = upgrade.description
	description_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	
	row.add_child(
		description_label
	)
	
	purchase_button.pressed.connect(
		func():
			_on_eternal_flame_upgrade_pressed(
				upgrade_id
			)
	)
	
	eternal_flame_upgrade_rows[upgrade_id] = {
		"name_label": name_label,
		"level_label": level_label,
		"cost_label": cost_label,
		"purchase_button": purchase_button,
		"description_label": description_label
	}


# ----------------------------------------------------------------
# Panel Switching
# ----------------------------------------------------------------

func _show_distribution_panel() -> void:
	if distribution_panel == null:
		return
	
	distribution_panel.visible = true
	shop_panel.visible = false
	
	distribution_button.disabled = true
	shop_button.disabled = false


func _show_shop_panel() -> void:
	if shop_panel == null:
		return
	
	distribution_panel.visible = false
	shop_panel.visible = true
	
	distribution_button.disabled = false
	shop_button.disabled = true
	
	_refresh_eternal_flame_upgrade_ui()


# ----------------------------------------------------------------
# Realm Interaction
# ----------------------------------------------------------------

func _on_stabilize_realm_pressed() -> void:
	if state == null:
		return
	
	if state.stabilize_realm():
		refresh()
		
		save_manager.save_game(
			state,
			time_manager
		)


func _on_realm_plus_pressed(
	stat_name: String
	) -> void:
	
	if state == null:
		return
	
	if state.realm_stabilized:
		return
	
	if state.get_unassigned_eternal_flames() <= 0:
		return
	
	if state.realm_configuration.assign_flame(
		stat_name
	):
		state.realm_effects.rebuild(
			state.realm_configuration,
			state.eternal_flame_state,
			state.eternal_flame_upgrade_manager,
			state.heat_leak_threshold,
			state.matter_decay_threshold
		)
		
		refresh()
		
		save_manager.save_game(
			state,
			time_manager
		)


func _on_realm_minus_pressed(
	stat_name: String
	) -> void:
	
	if state == null:
		return
	
	if state.realm_stabilized:
		return
	
	if state.realm_configuration.remove_flame(
		stat_name
	):
		state.realm_effects.rebuild(
			state.realm_configuration,
			state.eternal_flame_state,
			state.eternal_flame_upgrade_manager,
			state.heat_leak_threshold,
			state.matter_decay_threshold
		)
		
		refresh()
		
		save_manager.save_game(
			state,
			time_manager
		)


# ----------------------------------------------------------------
# Prestige Refresh
# ----------------------------------------------------------------

func refresh() -> void:
	if state == null:
		return
	
	var crystallized_flame = (
		state.get_resource_amount(
			ResourceIds.CRYSTALIZED_FLAME
		)
	)
	
	var eternal_flame = (
		state.eternal_flame_state.eternal_flame
	)
	
	var eternal_flame_gain = (
		prestige_system.calculate_eternal_flame_gain(
			state
		)
	)
	
	crystallized_flame_label.text = (
		"Crystallized Flame: %.0f"
		% crystallized_flame
	)
	
	eternal_flame_label.text = (
		"Eternal Flame: %.0f"
		% eternal_flame
	)
	
	gain_label.text = (
		"Eternal Flame on Smash: +%.0f"
		% eternal_flame_gain
	)
	
	smash_button.disabled = (
		eternal_flame_gain <= 0.0
		or not state.realm_stabilized
	)
	
	_refresh_realm_ui()
	_refresh_eternal_flame_upgrade_ui()
	
	if stabilize_button != null:
		stabilize_button.visible = not state.realm_stabilized
		stabilize_button.disabled = state.realm_stabilized


func _refresh_realm_ui() -> void:
	if realm_container == null:
		return
	
	var configuration = state.realm_configuration
	
	var assigned = (
		configuration.get_assigned_flames()
	)
	
	var available = (
		state.get_unassigned_eternal_flames()
	)
	
	var total = int(
		state.eternal_flame_state.eternal_flame
	)
	
	realm_available_label.text = (
		"Unassigned Eternal Flames: %d"
		% available
	)
	
	realm_assigned_label.text = (
		"Assigned to Realm: %d / %d"
		% [
			assigned,
			total
		]
	)
	
	for stat_name in realm_rows:
		var value = (
			configuration.get_stat_value(
				stat_name
			)
		)
		
		var row = realm_rows[stat_name]

		row["value_label"].text = str(value)

		row["effect_label"].text = (
			_get_realm_effect_text(stat_name)
		)
		
		row["minus_button"].disabled = (
			state.realm_stabilized
			or value <= 0
		)
		
		row["plus_button"].disabled = (
			state.realm_stabilized
			or available <= 0
		)


func _get_realm_effect_text(
	stat_name: String
	) -> String:
	
	var effects = state.realm_effects
	
	match stat_name:
		"stability":
			var threshold_multiplier = (
				effects.heat_leak_threshold
				/ state.heat_leak_threshold
			)
			
			return (
				"Heat Leak Threshold: x%.2f"
				% threshold_multiplier
			)
		
		"density":
			var matter_decay_multiplier = (
				effects.matter_decay_threshold
				/ state.matter_decay_threshold
			)
			
			return (
				"Thermal Mass: x%.2f\n"
				+ "Matter Production: x%.2f\n"
				+ "Matter Decay Threshold: x%.2f"
			) % [
				effects.thermal_mass_multiplier,
				effects.matter_production_multiplier,
				matter_decay_multiplier
			]
		
		"integrity":
			var generator_cost_reduction = (
				1.0
				- effects.generator_cost_multiplier
			) * 100.0
			
			return (
				"Generator Cost: x%.2f (-%.1f%%)\n"
				+ "Ashen Contamination Resistance: x%.2f"
			) % [
				effects.generator_cost_multiplier,
				generator_cost_reduction,
				effects.ashen_contamination_multiplier
			]
		
		"intensity":
			return (
				"Heat Production: x%.2f"
				% effects.heat_production_realm_multiplier
			)
		
		"resonance":
			return "No effect"
	
	return ""


# ----------------------------------------------------------------
# Smash
# ----------------------------------------------------------------

func _on_smash_button_pressed() -> void:
	if state == null:
		return
	
	if not state.realm_stabilized:
		return
	
	var eternal_flame_gain = (
		prestige_system.smash(
			state
		)
	)
	
	if eternal_flame_gain <= 0.0:
		return
	
	print(
		"Smash! Gained ",
		eternal_flame_gain,
		" Eternal Flame."
	)
	
	refresh()
	
	run_reset.emit()
	
	save_manager.save_game(
		state,
		time_manager
	)

# ----------------------------------------------------------------
# Eternal Flame Shop
# ----------------------------------------------------------------

func _on_eternal_flame_upgrade_pressed(
	upgrade_id: String
	) -> void:
	
	if state == null:
		return
	
	var upgrade = (
		state.eternal_flame_upgrade_manager.get_upgrade(
			upgrade_id
		)
	)
	
	if upgrade == null:
		return
	
	if not state.eternal_flame_upgrade_manager.purchase(
		upgrade_id,
		state.eternal_flame_state,
		state.realm_configuration
	):
		return
	
	state.realm_effects.rebuild(
		state.realm_configuration,
		state.eternal_flame_state,
		state.eternal_flame_upgrade_manager,
		state.heat_leak_threshold,
		state.matter_decay_threshold
	)
	
	if upgrade.effect_type == (
		EternalFlameUpgrade.EFFECT_UNLOCK_TECHNOLOGY
	):
		technology_unlocked.emit(
			upgrade.technology_id
		)
	
	refresh()
	
	save_manager.save_game(
		state,
		time_manager
	)


func _refresh_eternal_flame_upgrade_ui() -> void:
	if eternal_flame_upgrade_container == null:
		return
	
	for upgrade_id in eternal_flame_upgrade_rows:
		var upgrade = (
			state.eternal_flame_upgrade_manager.get_upgrade(
				upgrade_id
			)
		)
		
		if upgrade == null:
			continue
		
		var level = (
			state.eternal_flame_upgrade_manager.get_upgrade_level(
				upgrade_id,
				state.eternal_flame_state
			)
		)
		
		var cost = (
			state.eternal_flame_upgrade_manager.get_upgrade_cost(
				upgrade_id,
				state.eternal_flame_state
			)
		)
		
		var row = eternal_flame_upgrade_rows[upgrade_id]
		
		row["level_label"].text = (
			"Lv. %d / %d"
			% [
				level,
				upgrade.max_level
			]
		)
		
		if level >= upgrade.max_level:
			row["cost_label"].text = "MAX"
			row["purchase_button"].text = "MAX"
			row["purchase_button"].disabled = true
		else:
			row["cost_label"].text = (
				"%d Flame"
				% cost
			)
			
			row["purchase_button"].text = "BUY"
			
			row["purchase_button"].disabled = (
				state.get_unassigned_eternal_flames() < cost
			)


# ----------------------------------------------------------------
# Process
# ----------------------------------------------------------------

func _process(_delta: float) -> void:
	if not visible:
		return
	
	refresh()
