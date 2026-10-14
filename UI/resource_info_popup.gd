class_name ResourceInfoPopup
extends PanelContainer


const POPUP_WIDTH := 290.0

var state: GameState
var stats: GameStats
var resource_id: String = ""

var name_label: Label
var description_label: Label
var amount_label: Label
var rates_label: Label
var mechanics_label: Label
var modifiers_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = POPUP_WIDTH
	z_index = 100
	_build_content()
	_apply_style()
	hide()


func setup(game_state: GameState, game_stats: GameStats, id: String) -> void:
	state = game_state
	stats = game_stats
	resource_id = id
	_refresh_content()


func refresh() -> void:
	_refresh_content()


func _build_content() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	name_label = _create_label(15, true)
	column.add_child(name_label)

	description_label = _create_label(12)
	description_label.add_theme_color_override("font_color", Color(0.78, 0.75, 0.72))
	column.add_child(description_label)

	amount_label = _create_label(13, true)
	column.add_child(amount_label)

	column.add_child(_create_separator())

	column.add_child(_create_heading("FLOW"))
	rates_label = _create_label(12)
	column.add_child(rates_label)

	column.add_child(_create_separator())

	column.add_child(_create_heading("BASE MECHANICS"))
	mechanics_label = _create_label(12)
	column.add_child(mechanics_label)

	column.add_child(_create_separator())

	column.add_child(_create_heading("ACTIVE MODIFIERS"))
	modifiers_label = _create_label(12)
	column.add_child(modifiers_label)


func _create_label(font_size: int, strong: bool = false) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if strong:
		label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.58))
	return label


func _create_heading(text: String) -> Label:
	var label := _create_label(10, true)
	label.text = text
	label.add_theme_color_override("font_color", Color(0.88, 0.57, 0.38))
	return label


func _create_separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return separator


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.045, 0.055, 0.97)
	style.border_color = Color(0.42, 0.29, 0.25, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(0)
	add_theme_stylebox_override("panel", style)


func _refresh_content() -> void:
	if state == null or stats == null or resource_id == "":
		return

	name_label.text = state.get_resource_display_name(resource_id)
	description_label.text = _get_resource_description_text()
	amount_label.text = "Current: %s" % NumberFormatter.format(
		state.get_resource_amount(resource_id)
	)

	var production := stats.get_resource_actual_production_per_second(resource_id)
	var consumption := stats.get_resource_actual_consumption_per_second(resource_id)
	var net := production - consumption
	rates_label.text = (
		"Produced: +%s /s\nConsumed / lost: -%s /s\nNet after outflow: %s /s"
		% [
			NumberFormatter.format(production),
			NumberFormatter.format(consumption),
			NumberFormatter.format(net)
		]
	)

	mechanics_label.text = _get_base_mechanics_text()
	modifiers_label.text = _get_active_modifiers_text()
	reset_size()


func _get_resource_description_text() -> String:
	match resource_id:
		ResourceIds.HEAT:
			return "The realm's primary energy source. Heat powers most industrial processes, but excess Heat leaks away."
		ResourceIds.MATTER:
			return "The realm's physical substance. Matter enables advanced production and gradually decays when stockpiled beyond its threshold."
		ResourceIds.ASH:
			return "A by-product of infernal industry. Accumulated Ash contaminates production, while Lava Mites consume it."
		ResourceIds.CRYSTALLIZED_FLAME:
			return "A permanent-feeling prize from Infernal Forge cycles that remains in the current run. Each stored Flame makes Heat harder to produce."
		ResourceIds.ESSENCE:
			return "A rare substance extracted by advanced Lava Mite colonies. Stored Essence intensifies their hunger and helps resist Crystallization."
		ResourceIds.NEXUM:
			return "A condensed resource for advanced systems. Its broader uses are not yet available."
		ResourceIds.CHUNKS:
			return "A raw material reserved for future systems. Its broader uses are not yet available."
		_:
			return "A resource used by the realm's generators and industrial systems."


func _get_base_mechanics_text() -> String:
	match resource_id:
		ResourceIds.HEAT:
			return (
				"Overflow threshold: %s Heat\nCurrent Heat loss: %s /s"
				% [
					NumberFormatter.format(state.realm_effects.heat_leak_threshold),
					NumberFormatter.format(state.get_heat_leak_per_second())
				]
			)
		ResourceIds.MATTER:
			var thermic_mass_multiplier := (
				stats.get_raw_resource_modifier_multiplier(
					"thermic_mass",
					ModifierTypes.PRODUCTION,
					ResourceIds.HEAT
				)
			)
			return (
				(
					"Decay threshold: %s Matter\n"
					+ "Current Matter decay: %s /s\n"
					+ "Thermic Mass — Heat production: ×%s"
				)
				% [
					NumberFormatter.format(state.realm_effects.matter_decay_threshold),
					NumberFormatter.format(state.get_matter_decay_per_second()),
					NumberFormatter.format(thermic_mass_multiplier)
				]
			)
		ResourceIds.ASH:
			var contamination_multiplier := stats.get_raw_resource_modifier_multiplier(
				"ashen_contamination",
				ModifierTypes.PRODUCTION,
				""
			)
			return (
				"Ashen Contamination starts above 100 Ash.\n"
				+ "Current Ashen Contamination: ×%s"
				% NumberFormatter.format(contamination_multiplier)
			)
		ResourceIds.CRYSTALLIZED_FLAME:
			return "Produced by the Infernal Forge. Each current Flame reduces Heat production."
		ResourceIds.ESSENCE:
			return (
				"A rare resource tied to advanced demonic systems.\n"
				+ "Stored Essence strengthens Lava Mite Hunger and grants Crystallization Resistance."
			)
		ResourceIds.NEXUM:
			return "A resource reserved for systems that use Nexum."
		ResourceIds.CHUNKS:
			return "A resource reserved for systems that use Chunks."
		_:
			return "Produced and consumed by unlocked generators."


func _get_active_modifiers_text() -> String:
	match resource_id:
		ResourceIds.HEAT:
			return (
				"Realm — Intensity: ×%s production\nEternal Furnace: ×%s production"
				% [
					NumberFormatter.format(state.realm_effects.heat_production_realm_multiplier),
					NumberFormatter.format(state.realm_effects.heat_production_upgrade_multiplier)
				]
			)
		ResourceIds.MATTER:
			return "Realm — Density: ×%s production" % NumberFormatter.format(
				state.realm_effects.matter_production_multiplier
			)
		ResourceIds.ASH:
			return "Realm — Integrity: ×%s Ash resistance" % NumberFormatter.format(
				state.realm_effects.ashen_contamination_multiplier
			)
		ResourceIds.ESSENCE:
			var essence_amount := state.get_resource_amount(ResourceIds.ESSENCE)
			var hunger_multiplier := 1.0 + 0.01 * sqrt(essence_amount)
			var crystallization_sensitivity := 1.0 / (1.0 + 0.01 * sqrt(essence_amount))
			var resistance_percent := (1.0 - crystallization_sensitivity) * 100.0
			return (
				(
					"Lava Mite Hunger: ×%s input draw for the colony.\n"
					+ "Crystallization Resistance: %s%% less sensitivity (×%s remaining)."
				)
				% [
					NumberFormatter.format(hunger_multiplier),
					NumberFormatter.format(resistance_percent),
					NumberFormatter.format(crystallization_sensitivity)
				]
			)
		ResourceIds.CRYSTALLIZED_FLAME:
			var count := state.get_resource_amount(ResourceIds.CRYSTALLIZED_FLAME)
			return "Heat production penalty per current Flame: ×0.8\nCurrent stack: %s" % NumberFormatter.format(count)
		_:
			return "No resource-specific realm modifier."
