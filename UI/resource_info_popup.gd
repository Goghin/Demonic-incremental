class_name ResourceInfoPopup
extends PanelContainer


const POPUP_WIDTH := 290.0

var state: GameState
var stats: GameStats
var resource_id: String = ""

var name_label: Label
var resource_icon: ResourceIcon
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

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 7)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_row)

	resource_icon = ResourceIcon.new()
	resource_icon.name = "ResourceIcon"
	resource_icon.setup(resource_id, Vector2(22.0, 22.0))
	resource_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(resource_icon)

	name_label = _create_label(15, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_label)

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
	resource_icon.setup(resource_id, Vector2(22.0, 22.0))
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
			return "The realm's primary energy source. Heat powers many processes, but excess Heat above the threshold causes Overflow."
		ResourceIds.MATTER:
			return "The realm's physical substance. Matter enables advanced production and gradually decays when stockpiled beyond its threshold. Stored Matter also increases all Heat production."
		ResourceIds.ASH:
			return "A by-product of infernal industry. Accumulated Ash contaminates production, while Lava Mites consume it."
		ResourceIds.CRYSTALLIZED_FLAME:
			return "A highly prized product of the Infernal Forge. Each Crystallized Flame draws power from the realm, making Heat progressively harder to produce."
		ResourceIds.ESSENCE:
			return "A rare, highly volatile substance that intensifies Lava Mite activity and weakens the Heat production penalty caused by Crystallized Flames."
		ResourceIds.NEXUM:
			return "Highly condensed Matter bound by arcane sigils. Matter stored as Nexum does not decay, but does not contribute to the Heat production bonus. Nexum is also used in advanced processes."
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
			var modifier_data := stats.get_crystallization_modifier_data()
			return "Raw Heat penalty: ×" + NumberFormatter.format(
				modifier_data["raw_multiplier"]
			)
		ResourceIds.ESSENCE:
			var essence_data := stats.get_essence_influence_data()
			var modifier_data := stats.get_crystallization_modifier_data()
			return (
				"Lava Mite Activity: ×"
				+ NumberFormatter.format(essence_data["hunger_multiplier"])
				+ "\nBase Crystallization Resistance: "
				+ NumberFormatter.format(modifier_data["essence_resistance_percent"])
				+ "%\nBase Heat production multiplier: ×"
				+ NumberFormatter.format(modifier_data["effective_multiplier"])
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
			return "No direct modifiers to Essence production."
		ResourceIds.CRYSTALLIZED_FLAME:
			return "No direct modifiers to Crystallized Flame production."
		_:
			return "No resource-specific realm modifier."
