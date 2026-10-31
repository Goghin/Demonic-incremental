
class_name PrestigePanel
extends Control


signal technology_unlocked(technology_id: String)
signal run_reset
signal prestige_requested
signal planning_started

var state: GameState
var prestige_system: PrestigeSystem
var save_manager: SaveManager
var time_manager: TimeManager


# ----------------------------------------------------------------
# Main UI
# ----------------------------------------------------------------

var content_container: VBoxContainer

var tab_container: HBoxContainer
var prestige_button: Button
var shop_button: Button
var distribution_button: Button
var reliquary_button: Button

var prestige_panel: VBoxContainer
var distribution_panel: VBoxContainer
var shop_panel: VBoxContainer
var reliquary_panel: ReliquaryPanel
var planning_container: VBoxContainer
var planning_report_label: Label
var planning_bonus_label: Label
var begin_next_realm_button: Button


# ----------------------------------------------------------------
# Realm / Flame Distribution
# ----------------------------------------------------------------

var realm_container: VBoxContainer
var realm_available_label: Label
var realm_assigned_label: Label
var stabilize_button: Button

var realm_rows: Dictionary = {}

const BRAZIER_TECHNOLOGY_BY_STAT: Dictionary = {
	"stability": "brazier_stability",
	"density": "brazier_density",
	"integrity": "brazier_integrity",
	"intensity": "brazier_intensity",
	"resonance": "brazier_resonance"
}


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
	$ScrollContainer/VBoxContainer/CrystallizedFlameLabel
)

@onready var eternal_flame_label: Label = (
	$ScrollContainer/VBoxContainer/EternalFlameLabel
)

@onready var gain_label: Label = (
	$ScrollContainer/VBoxContainer/GainLabel
)

@onready var smash_button: Button = (
	$ScrollContainer/VBoxContainer/SmashButton
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

	# Debug why Smash is unavailable when the pointer enters its button.
	if not smash_button.mouse_entered.is_connected(_debug_smash_button_hover):
		smash_button.mouse_entered.connect(_debug_smash_button_hover)

	_create_main_ui()
	_add_crystallized_flame_icon()
	_create_distribution_ui()
	_create_shop_ui()
	_create_planning_ui()
	_apply_compact_style()
	_show_prestige_panel()

	refresh()


func _add_crystallized_flame_icon() -> void:
	if not is_instance_valid(crystallized_flame_label):
		return

	var parent := crystallized_flame_label.get_parent()
	if parent == null:
		return

	var existing_parent := parent.get_parent()
	if existing_parent is HBoxContainer and existing_parent.get_child_count() > 0:
		if existing_parent.get_child(0) is ResourceIcon:
			return

	var original_index: int = crystallized_flame_label.get_index()
	parent.remove_child(crystallized_flame_label)

	var row := HBoxContainer.new()
	row.name = "CrystallizedFlameRow"
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon := ResourceIcon.new()
	icon.name = "CrystallizedFlameIcon"
	icon.setup(ResourceIds.CRYSTALLIZED_FLAME, Vector2(18.0, 18.0))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	crystallized_flame_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(crystallized_flame_label)
	parent.add_child(row)
	parent.move_child(row, original_index)


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

	$ScrollContainer/VBoxContainer.add_child(
		content_container
	)

	_create_tab_ui()
	_create_prestige_stats_panel()
	_create_overflow_bonus_label()


func _create_planning_ui() -> void:
	if planning_container != null:
		return
	planning_container = VBoxContainer.new()
	planning_container.name = "PrestigePlanningContainer"
	planning_container.add_theme_constant_override("separation", 9)
	content_container.add_child(planning_container)
	content_container.move_child(planning_container, 0)

	var title := Label.new()
	title.text = "REALM SMASHED"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.38))
	planning_container.add_child(title)

	planning_report_label = Label.new()
	planning_report_label.name = "PrestigeReportLabel"
	planning_report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	planning_report_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	planning_report_label.add_theme_font_size_override("font_size", 12)
	planning_report_label.add_theme_color_override("font_color", Color(0.86, 0.80, 0.73))
	planning_container.add_child(planning_report_label)

	planning_bonus_label = Label.new()
	planning_bonus_label.name = "PrestigeBonusLabel"
	planning_bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	planning_bonus_label.add_theme_font_size_override("font_size", 12)
	planning_bonus_label.add_theme_color_override("font_color", Color(1.0, 0.77, 0.43))
	planning_container.add_child(planning_bonus_label)

	begin_next_realm_button = Button.new()
	begin_next_realm_button.name = "BeginNextRealmButton"
	begin_next_realm_button.text = "BEGIN NEXT REALM"
	begin_next_realm_button.custom_minimum_size = Vector2(0, 32)
	begin_next_realm_button.pressed.connect(_on_begin_next_realm_pressed)
	planning_container.add_child(begin_next_realm_button)
	planning_container.hide()


func _refresh_planning_ui() -> void:
	if planning_container == null or state == null:
		return
	var planning: bool = state.prestige_planning
	planning_container.visible = planning
	smash_button.visible = not planning
	if not planning:
		begin_next_realm_button.disabled = false
		return

	var report: Dictionary = state.last_prestige_report
	var generators: Array = report.get("generators_reached", [])
	var generators_text: String = ", ".join(PackedStringArray(generators)) if not generators.is_empty() else "None"

	planning_report_label.text = (
		"REWARDS\n"
		+ "Eternal Flames earned: +%s\n\n" % NumberFormatter.format(int(report.get("eternal_flames_gained", 0.0)))
		+ "REALM PERFORMANCE\n"
		+ "Survival time: %s\n" % _format_report_duration(float(report.get("survival_seconds", 0.0)))
		+ "Peak Heat: %s\n" % NumberFormatter.format(float(report.get("peak_heat", 0.0)))
		+ "Peak Matter: %s\n" % NumberFormatter.format(float(report.get("peak_matter", 0.0)))
		+ "Crystallized Flame: %s\n" % NumberFormatter.format(float(report.get("crystallized_flame", 0.0)))
		+ "Heat Overflow: %s\n" % NumberFormatter.format(float(report.get("total_overflow", 0.0)))
		+ "Matter Decayed: %s\n" % NumberFormatter.format(float(report.get("total_matter_decayed", 0.0)))
		+ "Environmental Bonus: x%.2f\n\n" % float(report.get("environmental_multiplier", 1.0))
		+ "PROGRESSION\n"
		+ "Generators reached: " + generators_text
	)
	var first_prestige: bool = int(report.get("prestige_count", 0)) == 1
	planning_bonus_label.visible = first_prestige
	if first_prestige:
		planning_bonus_label.text = (
			"FIRST-PRESTIGE BONUSES\n"
			+ "Eternal Furnace and Accelerated Friction (free)"
	)


func _format_report_duration(seconds: float) -> String:
	var total_seconds: int = maxi(0, int(seconds))
	var hours: int = total_seconds / 3600
	var minutes: int = (total_seconds % 3600) / 60
	var remainder: int = total_seconds % 60
	if hours > 0:
		return "%dh %02dm %02ds" % [hours, minutes, remainder]
	return "%dm %02ds" % [minutes, remainder]


func _on_begin_next_realm_pressed() -> void:
	if state == null or time_manager == null or not state.prestige_planning:
		return
	begin_next_realm_button.disabled = true
	if not prestige_system.begin_next_realm(state):
		begin_next_realm_button.disabled = false
		return
	time_manager.reset_prestige_time()
	time_manager.cancel_stabilization_countdown()
	refresh()
	run_reset.emit()
	save_manager.save_game(state, time_manager)


func _apply_compact_style() -> void:
	# Main panel spacing.
	$ScrollContainer/VBoxContainer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	$ScrollContainer/VBoxContainer.add_theme_constant_override(
		"separation",
		1
	)

	content_container.add_theme_constant_override(
		"separation",
		4
	)

	# Give prestige resources and the next reward distinct visual weight.
	crystallized_flame_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.57, 0.34)
	)
	eternal_flame_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.76, 0.39)
	)
	gain_label.add_theme_color_override(
		"font_color",
		Color(0.79, 0.91, 0.67)
	)

	for label in [
		crystallized_flame_label,
		eternal_flame_label,
		gain_label
	]:
		label.add_theme_font_size_override("font_size", 12)

	# Compact prestige action button.
	smash_button.custom_minimum_size = Vector2(0, 30)
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

	for button in [prestige_button, shop_button, distribution_button]:
		if button != null:
			# Equal minimum widths prevent the disabled/selected theme
			# from changing the layout when a tab is clicked.
			button.custom_minimum_size = Vector2(0, 28)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	# Keep the Realm panel visually consistent with the game's navigation.
	for button in [prestige_button, shop_button, distribution_button]:
		if button != null:
			_style_realm_button(button, true)

	_style_realm_button(smash_button, false)
	if stabilize_button != null:
		_style_realm_button(stabilize_button, false)

	for stat_name in realm_rows:
		var row = realm_rows[stat_name]
		for key in ["minus_button", "plus_button", "minus_10_button", "plus_10_button"]:
			_style_realm_button(row[key], false)

	if realm_available_label != null:
		realm_available_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.38))
	if realm_assigned_label != null:
		realm_assigned_label.add_theme_color_override("font_color", Color(0.88, 0.78, 0.70))


func _make_realm_style(
	background_color: Color,
	border_color: Color,
	border_width: int = 1
	) -> StyleBoxFlat:

	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	style.content_margin_left = 7.0
	style.content_margin_top = 4.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 4.0
	return style


func _style_realm_button(button: Button, is_tab: bool) -> void:
	if button == null:
		return

	var normal := _make_realm_style(
		Color(0.075, 0.055, 0.06, 1.0),
		Color(0.30, 0.19, 0.17, 1.0)
	)
	var hover := _make_realm_style(
		Color(0.14, 0.085, 0.065, 1.0),
		Color(0.62, 0.32, 0.18, 1.0)
	)
	var pressed := _make_realm_style(
		Color(0.24, 0.115, 0.065, 1.0),
		Color(0.92, 0.48, 0.20, 1.0),
		2
	)
	var active := _make_realm_style(
		Color(0.19, 0.095, 0.065, 1.0),
		Color(0.78, 0.38, 0.18, 1.0),
		1
	)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", active)
	button.add_theme_color_override("font_color", Color(0.91, 0.82, 0.74))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.70))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.94, 0.82))

	if is_tab:
		button.add_theme_stylebox_override("disabled", active)
		button.add_theme_color_override("font_disabled_color", Color(1.0, 0.72, 0.38))


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

	prestige_panel.add_child(overflow_bonus_label)
	prestige_panel.move_child(
		overflow_bonus_label,
		smash_button.get_index()
	)


func _create_prestige_stats_panel() -> void:
	if prestige_panel != null:
		return

	prestige_panel = VBoxContainer.new()
	prestige_panel.name = "PrestigeStatsPanel"
	prestige_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prestige_panel.add_theme_constant_override("separation", 6)
	content_container.add_child(prestige_panel)

	# Keep the existing prestige labels and Smash action together in
	# the first tab rather than above the navigation buttons.
	var original_parent := $ScrollContainer/VBoxContainer
	for control in [
		$ScrollContainer/VBoxContainer/TitleLabel,
		crystallized_flame_label,
		eternal_flame_label,
		gain_label,
		smash_button
	]:
		original_parent.remove_child(control)
		prestige_panel.add_child(control)

	var heading: Label = prestige_panel.get_node("TitleLabel")
	heading.text = "PRESTIGE STATS & SCORE"
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color(1.0, 0.72, 0.38))


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

	prestige_button = Button.new()
	prestige_button.name = "PrestigeStatsButton"
	prestige_button.text = "PRESTIGE & SMASH"
	prestige_button.custom_minimum_size = Vector2(0, 40)
	prestige_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.add_child(prestige_button)
	prestige_button.pressed.connect(_show_prestige_panel)

	shop_button = Button.new()
	shop_button.name = "EternalFlameShopButton"
	shop_button.text = "FLAME SHOP"
	shop_button.custom_minimum_size = Vector2(0, 40)
	shop_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.add_child(shop_button)
	shop_button.pressed.connect(_show_shop_panel)

	distribution_button = Button.new()
	distribution_button.name = "FlameDistributionButton"
	distribution_button.text = "FLAME DISTRIBUTION"
	distribution_button.custom_minimum_size = Vector2(0, 40)
	distribution_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.add_child(distribution_button)
	distribution_button.pressed.connect(_show_distribution_panel)


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

	var title := Label.new()
	title.text = "REALM ATTRIBUTES"
	title.custom_minimum_size = Vector2(0, 28)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.38))
	realm_container.add_child(title)

	realm_available_label = Label.new()
	realm_container.add_child(
		realm_available_label
	)

	realm_assigned_label = Label.new()
	realm_container.add_child(
		realm_assigned_label
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

	# Each realm attribute gets its own subtle industrial card.
	var row_card := PanelContainer.new()
	row_card.name = "%sCard" % stat_name
	row_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_card.add_theme_stylebox_override(
		"panel",
		_make_realm_style(
			Color(0.055, 0.045, 0.052, 0.96),
			Color(0.24, 0.16, 0.15, 0.95)
		)
	)
	realm_container.add_child(row_card)

	var row := VBoxContainer.new()
	row.name = "%sRow" % stat_name
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 3)
	row_card.add_child(row)

	var assignment_row = HBoxContainer.new()
	assignment_row.add_theme_constant_override(
		"separation",
		4
	)

	row.add_child(
		assignment_row
	)

	var label := Label.new()
	label.text = display_name.to_upper()
	label.custom_minimum_size = Vector2(82, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.86, 0.73, 0.64))

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
	effect_label.add_theme_font_size_override("font_size", 10)
	effect_label.add_theme_color_override("font_color", Color(0.70, 0.72, 0.72))
	effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	row.add_child(effect_label)

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
		"card": row_card,
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
	title.custom_minimum_size = Vector2(0, 28)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.38))
	shop_panel.add_child(title)

	eternal_flame_shop_available_label = Label.new()
	eternal_flame_shop_available_label.name = "EternalFlameShopAvailableLabel"
	eternal_flame_shop_available_label.text = "Available Eternal Flames: 0"
	shop_panel.add_child(eternal_flame_shop_available_label)

	eternal_flame_shop_scroll = ScrollContainer.new()
	eternal_flame_shop_scroll.name = "EternalFlameShopScroll"
	eternal_flame_shop_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eternal_flame_shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	eternal_flame_shop_scroll.custom_minimum_size = Vector2(0, 0)
	eternal_flame_shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	eternal_flame_shop_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
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


func _create_reliquary_ui() -> void:
	if reliquary_panel != null:
		return
	reliquary_panel = ReliquaryPanel.new()
	reliquary_panel.name = "ReliquaryPanel"
	reliquary_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(reliquary_panel)
	reliquary_panel.setup(state)
	reliquary_panel.relics_changed.connect(_on_relics_changed)
	reliquary_panel.hide()


func _on_relics_changed() -> void:
	state.rebuild_relic_modifiers()
	refresh()
	save_manager.save_game(state, time_manager)



# ----------------------------------------------------------------
# Panel Switching
# ----------------------------------------------------------------

func _show_prestige_panel() -> void:
	if prestige_panel == null:
		return

	prestige_panel.visible = true
	shop_panel.visible = false
	distribution_panel.visible = false
	if reliquary_panel != null:
		reliquary_panel.visible = false

	prestige_button.disabled = true
	shop_button.disabled = false
	distribution_button.disabled = false


func _show_shop_panel() -> void:
	if shop_panel == null or state == null:
		return

	if state.eternal_flame_state.prestige_count < 1:
		return

	prestige_panel.visible = false
	shop_panel.visible = true
	distribution_panel.visible = false
	if reliquary_panel != null:
		reliquary_panel.visible = false

	prestige_button.disabled = false
	shop_button.disabled = true
	distribution_button.disabled = false

	_refresh_eternal_flame_upgrade_ui()


func _show_distribution_panel() -> void:
	if distribution_panel == null or state == null:
		return
	if not state.prestige_planning or not _is_brazier_unlocked("stability"):
		return

	prestige_panel.visible = false
	shop_panel.visible = false
	distribution_panel.visible = true
	if reliquary_panel != null:
		reliquary_panel.visible = false

	prestige_button.disabled = false
	shop_button.disabled = false
	distribution_button.disabled = true


func _show_reliquary_panel() -> void:
	if reliquary_panel == null or state == null:
		return
	if not state.eternal_flame_upgrade_manager.is_reliquary_unlocked(state.eternal_flame_state):
		return
	prestige_panel.visible = false
	shop_panel.visible = false
	distribution_panel.visible = false
	reliquary_panel.visible = true
	prestige_button.disabled = false
	shop_button.disabled = false
	distribution_button.disabled = false
	reliquary_panel.refresh()




# ----------------------------------------------------------------
# Realm Interaction
# ----------------------------------------------------------------

func _on_realm_plus_pressed(
	stat_name: String
	) -> void:

	if state == null:
		return

	if not state.prestige_planning or not _is_brazier_unlocked(stat_name):
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

	if not state.prestige_planning or not _is_brazier_unlocked(stat_name):
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

	if not state.prestige_planning or not _is_brazier_unlocked(stat_name):
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

	_refresh_planning_ui()

	var crystallized_flame = (
		state.get_resource_amount(
			ResourceIds.CRYSTALLIZED_FLAME
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
		"Crystallized Flame: %s"
		% NumberFormatter.format(crystallized_flame)
	)

	eternal_flame_label.text = (
		"Eternal Flame: %s"
		% NumberFormatter.format(eternal_flame)
	)

	gain_label.text = (
		"Eternal Flame on Smash: +%s"
		% NumberFormatter.format(eternal_flame_gain)
	)

	smash_button.disabled = eternal_flame_gain <= 0.0 or state.prestige_planning

	# The shop unlocks after the first Smash; distribution unlocks with Brazier I.
	shop_button.visible = state.eternal_flame_state.prestige_count > 0
	distribution_button.visible = _is_brazier_unlocked("stability")
	distribution_button.disabled = not state.prestige_planning or distribution_panel.visible

	_update_overflow_bonus_ui()
	_refresh_realm_ui()
	_refresh_eternal_flame_upgrade_ui()
	if reliquary_panel != null and reliquary_panel.visible:
		reliquary_panel.refresh()

	if stabilize_button != null:
		stabilize_button.hide()



func _update_overflow_bonus_ui() -> void:
	if state == null or overflow_bonus_label == null:
		return

	var crystallized_flame: float = state.get_resource_amount(
		ResourceIds.CRYSTALLIZED_FLAME
	)
	var infernal_forge: Generator = state.get_generator("infernal_forge")
	var heat_multiplier: float = state.get_heat_overflow_bonus()
	var matter_multiplier: float = state.get_matter_decay_bonus()
	var combined_multiplier: float = state.get_combined_environmental_reward_multiplier()

	var base_gain: int = 0
	var final_gain: int = 0
	if infernal_forge != null:
		var forge_level: int = infernal_forge.level
		if forge_level > 0 and crystallized_flame > 0.0:
			base_gain = floori(crystallized_flame * sqrt(float(forge_level)))
			final_gain = floori(
				crystallized_flame
				* sqrt(float(forge_level))
				* combined_multiplier
			)

	var environmental_contribution: int = max(0, final_gain - base_gain)
	overflow_bonus_label.text = (
		"Base Gain: %s\n"
		+ "Heat Overflow: %s (x%.2f)\n"
		+ "Matter Decayed: %s (x%.2f)\n"
		+ "Combined Environmental Multiplier: x%.2f\n"
		+ "Environmental Bonus Contribution: +%s"
	) % [
		NumberFormatter.format(base_gain),
		NumberFormatter.format(state.total_overflow_this_prestige),
		heat_multiplier,
		NumberFormatter.format(state.total_matter_decayed_this_prestige),
		matter_multiplier,
		combined_multiplier,
		NumberFormatter.format(environmental_contribution)
	]

func _is_brazier_unlocked(stat_name: String) -> bool:
	if state == null or not BRAZIER_TECHNOLOGY_BY_STAT.has(stat_name):
		return false
	return state.eternal_flame_state.is_technology_unlocked(
		str(BRAZIER_TECHNOLOGY_BY_STAT[stat_name])
	)


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
		"Unassigned Eternal Flames: %s"
		% NumberFormatter.format(available)
	)

	realm_assigned_label.text = (
		"Assigned to Realm: %s / %s"
		% [
			NumberFormatter.format(assigned),
			NumberFormatter.format(total)
		]
	)

	for stat_name in realm_rows:
		var value = (
			configuration.get_stat_value(
				stat_name
			)
		)

		var row = realm_rows[stat_name]

		row["value_label"].text = NumberFormatter.format(value)

		row["effect_label"].text = (
			_get_realm_effect_text(stat_name)
		)

		var unlocked: bool = _is_brazier_unlocked(stat_name)
		var can_edit: bool = state.prestige_planning and unlocked
		row["card"].visible = unlocked

		row["minus_button"].disabled = not can_edit or value <= 0
		row["plus_button"].disabled = not can_edit or available <= 0
		row["minus_10_button"].disabled = not can_edit or value <= 0
		row["plus_10_button"].disabled = not can_edit or available <= 0



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

func _debug_smash_button_hover() -> void:
	if state == null:
		print("[Smash Debug] Disabled: GameState is null.")
		return

	var reasons: Array[String] = []
	var eternal_flame_gain: float = prestige_system.calculate_eternal_flame_gain(state)

	if not state.realm_stabilized:
		reasons.append("realm is not stabilized")
	if eternal_flame_gain <= 0.0:
		reasons.append("Eternal Flame gain is %.6f (must be greater than 0)" % eternal_flame_gain)

	if reasons.is_empty():
		print("[Smash Debug] Button should be enabled. Gain: %.6f Eternal Flame." % eternal_flame_gain)
	else:
		print("[Smash Debug] Smash disabled: %s." % ", ".join(reasons))


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
	if state == null or time_manager == null or state.prestige_planning:
		return
	var eternal_flame_gain: float = prestige_system.smash(state, time_manager.prestige_time)
	if eternal_flame_gain <= 0.0:
		return
	print("Smash! Gained ", eternal_flame_gain, " Eternal Flame.")
	time_manager.cancel_stabilization_countdown()
	refresh()
	planning_started.emit()
	save_manager.save_game(state, time_manager)


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

	if upgrade.effect_type == EternalFlameUpgrade.EFFECT_UNLOCK_RELIQUARY:
		state.relic_manager.ensure_starter_relic()
		state.rebuild_relic_modifiers()

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
	if state == null or time_manager == null or state.prestige_planning:
		return

	if not visible:
		return

	refresh()
