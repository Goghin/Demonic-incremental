class_name RealmSceneVisualController
extends RefCounted


func update(owner: Control) -> void:
	if owner.state == null or owner.realm_layout == null:
		return

	# Generator nodes and hitboxes are updated during the process phase,
	# not as a side effect of Control._draw().
	owner._draw_generators()

	# Lake fill must update before flow activation is evaluated.
	owner.lava_realm_visual_controller.update_dynamic_states(
		owner.state,
		owner.realm_layout
	)

	var island_rect: Rect2 = owner._get_island_rect()
	var state: GameState = owner.state
	var realm_layout: Resource = owner.realm_layout

	_update_ash_visuals(
		owner,
		owner.ash_visual_controller,
		state,
		realm_layout,
		island_rect,
		owner.size * owner.ISLAND_CENTER_RATIO,
		owner.ASH_VISUAL_RADIUS
	)
	_update_braziers(
		owner.brazier_visual_controller,
		owner.braziers,
		owner.BRAZIER_STATS,
		state.realm_configuration,
		realm_layout,
		island_rect
	)
	_update_forge_visuals(
		owner,
		owner.forge_activity_visual_controller,
		state.generators.get("infernal_forge"),
		owner._get_generator_position("infernal_forge")
	)
	_update_layout_overlay(owner)


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
	forge_controller.update(
		visual_parent,
		forge,
		forge_position
	)


func _update_layout_overlay(owner: Control) -> void:
	var overlay: RealmLayoutOverlayRenderer = owner.realm_layout_overlay_renderer
	var layout_mode: bool = owner.realm_layout_editor_controller.layout_mode

	# Refresh while editing, and once when leaving edit mode to clear the overlay.
	if not layout_mode and not overlay.overlay_enabled:
		return

	overlay.update_overlay(
		layout_mode,
		owner.generator_hitboxes,
		owner.ash_visual_controller.piles,
		owner.braziers,
		owner.BRAZIER_STATS
	)
