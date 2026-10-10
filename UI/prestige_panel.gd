
class_name PrestigePanel
extends Control


signal technology_unlocked(technology_id: String)
signal run_reset
signal prestige_requested

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
var eternal_flame_upgrade_container: EternalFlameShopTree
var eternal_flame_shop_available_label: Label


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

var overflow_bonus_label: Label


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
	_apply_compact_style()
	_show_distribution_panel()

	# Offline simulation can finish a stabilization countdown
	# before this panel exists.
	_check_stabilization_completion()

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

	_create_overflow_bonus_label()
	_create_tab_ui()


func _apply_compact_style() -> void:
	# Main panel spacing.
	$VBoxContainer.add_theme_constant_override(
		"separation",
		1
	)

	content_container.add_theme_constant_override(
		"separation",
		4
	)

	# Reduce the font size of the existing prestige labels.
	for label in [
		crystallized_flame_label,
		eternal_flame_label,
		gain_label
	]:
		label.add_theme_font_size_override(
			"font_size",
			12
		)

	# Compact prestige action button.
	smash_button.custom_minimum_size = Vector2(0, 25)
	smash_button.add_theme_font_size_override(
		"font_size",
		12
	)

	# Compact overflow breakdown.
	if overflow_bonus_label != null:
		overflow_bonus_label.add_theme_font_size_override(
			"font_size",
			10
		)

	# Compact tabs.
	if tab_container != null:
		tab_container.add_theme_constant_override(
			"separation",
			3
		)

	for button in [distribution_button, shop_button]:
		if button != null:
			button.custom_minimum_size = Vector2(0, 24)
			button.add_theme_font_size_override(
				"font_size",
				11
			)

	# Compact realm controls.
	if realm_container != null:
		realm_container.add_theme_constant_override(
			"separation",
			3
		)

	if stabilize_button != null:
		stabilize_button.custom_minimum_size = Vector2(0, 24)
		stabilize_button.add_theme_font_size_override(
			"font_size",
			11
		)

	for stat_name in realm_rows:
		var row = realm_rows[stat_name]

		for key in [
			"minus_button",
			"plus_button",
			"minus_10_button",
			"plus_10_button"
		]:
			var button: Button = row[key]
			button.custom_minimum_size = Vector2(
				button.custom_minimum_size.x,
				20
			)
			button.add_theme_font_size_override(
				"font_size",
				11
			)

		for key in ["value_label", "effect_label"]:
			var label: Label = row[key]
			label.add_theme_font_size_override(
				"font_size",
				11
			)

	# Compact Eternal Flame shop.
	if shop_panel != null:
		shop_panel.add_theme_constant_override(
			"separation",
			3
		)

	if eternal_flame_upgrade_container != null:
		eternal_flame_upgrade_container.add_theme_constant_override(
			"separation",
			4
		)


func _create_overflow_bonus_label() -> void:
	if overflow_bonus_label != null:
		return

	overflow_bonus_label = Label.new()
	overflow_bonus_label.name = "OverflowBonusLabel"

	overflow_bonus_label.add_theme_font_size_override(
		"font_size",
		12
	)

	overflow_bonus_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	overflow_bonus_label.modulate = Color(
		0.75,
		0.85,
		0.75
	)

	overflow_bonus_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	$VBoxContainer.add_child(
		overflow_bonus_label
	)

	$VBoxContainer.move_child(
		overflow_bonus_label,
		gain_label.get_index() + 1
	)

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
		4
	)

	row.add_child(
		assignment_row
	)

	var label = Label.new()
	label.text = display_name
	label.custom_minimum_size = Vector2(90, 0)

	assignment_row.add_child(label)

	var minus_10_button = Button.new()
	minus_10_button.text = "-10"
	minus_10_button.custom_minimum_size = Vector2(45, 30)

	assignment_row.add_child(
		minus_10_button
	)

	var minus_button = Button.new()
	minus_button.text = "-"
	minus_button.custom_minimum_size = Vector2(35, 30)

	assignment_row.add_child(
		minus_button
	)

	var value_label = Label.new()
	value_label.text = "0"
	value_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	value_label.custom_minimum_size = Vector2(45, 30)

	assignment_row.add_child(
		value_label
	)

	var plus_button = Button.new()
	plus_button.text = "+"
	plus_button.custom_minimum_size = Vector2(35, 30)

	assignment_row.add_child(
		plus_button
	)

	var plus_10_button = Button.new()
	plus_10_button.text = "+10"
	plus_10_button.custom_minimum_size = Vector2(45, 30)

	assignment_row.add_child(
		plus_10_button
	)

	var effect_label = Label.new()
	effect_label.text = ""
	effect_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	effect_label.modulate = Color(0.7, 0.7, 0.7)

	row.add_child(
		effect_label
	)

	minus_10_button.pressed.connect(
		func():
			_on_realm_batch_pressed(
				stat_name,
				-10
			)
	)

	minus_button.pressed.connect(
		func():
			_on_realm_minus_pressed(
				stat_name
			)
	)

	plus_button.pressed.connect(
		func():
			_on_realm_plus_pressed(
				stat_name
			)
	)

	plus_10_button.pressed.connect(
		func():
			_on_realm_batch_pressed(
				stat_name,
				10
			)
	)

	realm_rows[stat_name] = {
		"value_label": value_label,
		"minus_button": minus_button,
		"plus_button": plus_button,
		"minus_10_button": minus_10_button,
		"plus_10_button": plus_10_button,
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
	shop_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_panel.add_theme_constant_override("separation", 6)
	content_container.add_child(shop_panel)

	var title := Label.new()
	title.text = "ETERNAL FLAME SHOP"
	title.custom_minimum_size = Vector2(0, 30)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shop_panel.add_child(title)

	eternal_flame_shop_available_label = Label.new()
	eternal_flame_shop_available_label.name = "EternalFlameShopAvailableLabel"
	eternal_flame_shop_available_label.text = "Available Eternal Flames: 0"
	shop_panel.add_child(eternal_flame_shop_available_label)

	eternal_flame_shop_scroll = ScrollContainer.new()
	eternal_flame_shop_scroll.name = "EternalFlameShopScroll"
	eternal_flame_shop_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eternal_flame_shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	eternal_flame_shop_scroll.custom_minimum_size = Vector2(0, 100)
	eternal_flame_shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	eternal_flame_shop_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	shop_panel.add_child(eternal_flame_shop_scroll)

	eternal_flame_upgrade_container = EternalFlameShopTree.new()
	eternal_flame_upgrade_container.name = "EternalFlameShopTree"
	eternal_flame_upgrade_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eternal_flame_upgrade_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	eternal_flame_shop_scroll.add_child(eternal_flame_upgrade_container)
	eternal_flame_upgrade_container.purchase_requested.connect(
		_on_eternal_flame_upgrade_pressed
	)
	eternal_flame_upgrade_container.setup(state)


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
# Realm Stabilization
# ----------------------------------------------------------------

func _on_stabilize_realm_pressed() -> void:
	if state == null or time_manager == null:
		return

	if state.realm_stabilized:
		return

	if time_manager.is_stabilization_countdown_active():
		return

	if time_manager.start_stabilization_countdown():
		save_manager.save_game(
			state,
			time_manager
		)

		refresh()


func _check_stabilization_completion() -> void:
	if state == null or time_manager == null:
		return

	if not time_manager.is_stabilization_countdown_active():
		return

	if time_manager.get_stabilization_remaining() > 0.0:
		return

	if state.realm_stabilized:
		time_manager.cancel_stabilization_countdown()
		return

	if state.stabilize_realm():
		time_manager.cancel_stabilization_countdown()

		save_manager.save_game(
			state,
			time_manager
		)


func _format_stabilization_time(
	seconds: float
	) -> String:

	var remaining = max(
		0,
		int(ceil(seconds))
	)

	var minutes = int(
		remaining / 60
	)

	var seconds_part = int(
		remaining % 60
	)

	return "%02d:%02d" % [
		minutes,
		seconds_part
	]


# ----------------------------------------------------------------
# Realm Interaction
# ----------------------------------------------------------------

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



func _on_realm_batch_pressed(
	stat_name: String,
	amount: int
	) -> void:

	if state == null:
		return

	if state.realm_stabilized:
		return

	if amount == 0:
		return

	var changed: int = 0

	if amount > 0:
		var available: int = (
			state.get_unassigned_eternal_flames()
		)

		var amount_to_assign: int = min(
			amount,
			available
		)

		if amount_to_assign <= 0:
			return

		changed = state.realm_configuration.assign_flames(
			stat_name,
			amount_to_assign
		)
	else:
		var stat_value: int = (
			state.realm_configuration.get_stat_value(
				stat_name
			)
		)

		var amount_to_remove: int = min(
			abs(amount),
			stat_value
		)

		if amount_to_remove <= 0:
			return

		changed = state.realm_configuration.remove_flames(
			stat_name,
			amount_to_remove
		)

	if changed <= 0:
		return

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

	_update_overflow_bonus_ui()
	_refresh_realm_ui()
	_refresh_eternal_flame_upgrade_ui()

	if stabilize_button != null:
		if state.realm_stabilized:
			stabilize_button.visible = true
			stabilize_button.disabled = true
			stabilize_button.text = "REALM STABILIZED"
		elif time_manager != null and (
			time_manager.is_stabilization_countdown_active()
		):
			stabilize_button.visible = true
			stabilize_button.disabled = true
			stabilize_button.text = (
				"STABILIZING  %s"
				% _format_stabilization_time(
					time_manager.get_stabilization_remaining()
				)
			)
		else:
			stabilize_button.visible = true
			stabilize_button.disabled = false
			stabilize_button.text = "STABILIZE REALM"



func _update_overflow_bonus_ui() -> void:
	if state == null or overflow_bonus_label == null:
		return

	var crystallized_flame: float = (
		state.get_resource_amount(
			ResourceIds.CRYSTALIZED_FLAME
		)
	)

	var infernal_forge = state.get_generator(
		"infernal_forge"
	)

	var overflow_multiplier: float = (
		state.get_overflow_bonus()
	)

	var next_overflow_multiplier: float = (
		state.next_overflow_bonus()
	)

	var base_gain: int = 0
	var final_gain: int = 0

	if infernal_forge != null:
		var forge_level: int = infernal_forge.level

		if forge_level > 0 and crystallized_flame > 0.0:
			base_gain = floori(
				crystallized_flame
				* sqrt(float(forge_level))
			)

			final_gain = floori(
				crystallized_flame
				* sqrt(float(forge_level))
				* overflow_multiplier
			)

	var overflow_contribution: int = max(
		0,
		final_gain - base_gain
	)

	overflow_bonus_label.text = (
		"Base Gain: %d\n"
		+ "Current Overflow Multiplier: x%.2f\n"
		+ "Current Overflow Contribution: +%d\n"
		+ "Next Prestige Overflow Multiplier: x%.2f"
	) % [
		base_gain,
		overflow_multiplier,
		overflow_contribution,
		next_overflow_multiplier
	]

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

	var total: int = max(
		0,
		int(
			state.eternal_flame_state.eternal_flame
			- state.eternal_flame_state.spent_flames
		)
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

		var locked: bool = state.realm_stabilized

		row["minus_button"].disabled = (
			locked
			or value <= 0
		)

		row["plus_button"].disabled = (
			locked
			or available <= 0
		)

		row["minus_10_button"].disabled = (
			locked
			or value <= 0
		)

		row["plus_10_button"].disabled = (
			locked
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
		prestige_system.calculate_eternal_flame_gain(
			state
		)
	)

	if eternal_flame_gain <= 0.0:
		return

	print(
		"Prestige requested. Expected gain: ",
		eternal_flame_gain,
		" Eternal Flame."
	)

	smash_button.disabled = true

	prestige_requested.emit()


func perform_smash() -> void:
	if state == null:
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

	time_manager.reset_prestige_time()
	time_manager.start_stabilization_countdown()

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
	if eternal_flame_upgrade_container == null or state == null:
		return

	if eternal_flame_shop_available_label != null:
		eternal_flame_shop_available_label.text = (
			"Available Eternal Flames: %d"
			% state.get_unassigned_eternal_flames()
		)

	eternal_flame_upgrade_container.refresh()


# ----------------------------------------------------------------
# Process
# ----------------------------------------------------------------

func _process(_delta: float) -> void:
	if state == null or time_manager == null:
		return

	# This must run even when the Prestige panel is hidden.
	# Offline simulation or normal gameplay can finish the countdown
	# while the panel is not visible.
	_check_stabilization_completion()

	if not visible:
		return

	refresh()
