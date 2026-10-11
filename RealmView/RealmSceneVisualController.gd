class_name RealmSceneVisualController
extends RefCounted


# The view is only used as the visual parent for nodes and to invoke its
# existing generator-drawing entry point. All scene state is passed explicitly.
func update_from_view(visual_parent: Control) -> void:
	var view := visual_parent as RealmView
	if view == null or view.state == null or view.realm_layout == null:
		return

	update(
		visual_parent,
		view.state,
		view.realm_layout,
		Callable(view, "_draw_generators"),
		Callable(view, "_get_island_rect"),
		Callable(view, "_get_generator_position"),
		view.size,
		view.ISLAND_CENTER_RATIO,
		view.ASH_VISUAL_RADIUS,
		view.lava_realm_visual_controller,
		view.ash_visual_controller,
		view.brazier_visual_controller,
		view.braziers,
		view.BRAZIER_STATS,
		view.forge_activity_visual_controller,
		view.realm_layout_overlay_renderer,
		view.realm_layout_editor_controller.layout_mode,
		view.generator_hitboxes
	)


func update(
	visual_parent: Control,
	state: GameState,
	realm_layout: Resource,
	draw_generators: Callable,
	get_island_rect: Callable,
	get_generator_position: Callable,
	view_size: Vector2,
	island_center_ratio: Vector2,
	ash_visual_radius: float,
	lava_controller: LavaRealmVisualController,
	ash_controller: AshVisualController,
	brazier_controller: BrazierVisualController,
	braziers: Dictionary,
	brazier_stats: Array[String],
	forge_controller: ForgeActivityVisualController,
	layout_overlay: RealmLayoutOverlayRenderer,
	layout_mode: bool,
	generator_hitboxes: Dictionary
) -> void:
	if state == null or realm_layout == null:
		return

	# Generator nodes and hitboxes are updated during the process phase,
	# not as a side effect of Control._draw().
	draw_generators.call()

	# Lake fill must update before flow activation is evaluated.
	lava_controller.update_dynamic_states(state, realm_layout)

	var island_rect: Rect2 = get_island_rect.call()
	_update_ash_visuals(
		visual_parent,
		ash_controller,
		state,
		realm_layout,
		island_rect,
		view_size * island_center_ratio,
		ash_visual_radius
	)
	_update_braziers(
		brazier_controller,
		braziers,
		brazier_stats,
		state.realm_configuration,
		realm_layout,
		island_rect
	)
	_update_forge_visuals(
		visual_parent,
		forge_controller,
		state.generators.get("infernal_forge"),
		get_generator_position.call("infernal_forge")
	)
	_update_layout_overlay(
		layout_overlay,
		layout_mode,
		generator_hitboxes,
		ash_controller.piles,
		braziers,
		brazier_stats
	)


func _update_ash_visuals(
	visual_parent: Control,
	ash_controller: AshVisualController,
	state: GameState,
	realm_layout: Resource,
	island_rect: Rect2,
	center: Vector2,
	visual_radius: float
) -> void:
	var ash: float = state.get_resource_amount(ResourceIds.ASH)
	ash_controller.update_realm_visuals(
		visual_parent,
		realm_layout,
		island_rect,
		ash,
		center,
		visual_radius
	)


func _update_braziers(
	brazier_controller: BrazierVisualController,
	braziers: Dictionary,
	brazier_stats: Array[String],
	realm_configuration: RealmConfiguration,
	realm_layout: Resource,
	island_rect: Rect2
) -> void:
	brazier_controller.update_stat_values(
		braziers,
		brazier_stats,
		realm_configuration
	)
	brazier_controller.position_braziers(
		braziers,
		brazier_stats,
		realm_layout,
		island_rect
	)


func _update_forge_visuals(
	visual_parent: Control,
	forge_controller: ForgeActivityVisualController,
	forge: Generator,
	forge_position: Vector2
) -> void:
	forge_controller.update(visual_parent, forge, forge_position)


func _update_layout_overlay(
	overlay: RealmLayoutOverlayRenderer,
	layout_mode: bool,
	generator_hitboxes: Dictionary,
	ash_piles: Array,
	braziers: Dictionary,
	brazier_stats: Array[String]
) -> void:
	# Refresh while editing, and once when leaving edit mode to clear the overlay.
	if not layout_mode and not overlay.overlay_enabled:
		return

	overlay.update_overlay(
		layout_mode,
		generator_hitboxes,
		ash_piles,
		braziers,
		brazier_stats
	)
