class_name RealmSceneVisualController
extends RefCounted


func update(owner: RealmView, island_rect: Rect2) -> void:
	var state: GameState = owner.state
	var realm_layout: Resource = owner.realm_layout
	if state == null or realm_layout == null:
		return

	# Generator nodes and hitboxes must be current before dependent visuals.
	owner._draw_generators(island_rect)

	# Lake fill must update before flow activation is evaluated.
	owner.lava_realm_visual_controller.update_dynamic_states(state, realm_layout)

	_update_ash_visuals(owner, island_rect)
	_update_braziers(owner, island_rect)
	_update_forge_visuals(owner, island_rect)
	_update_layout_overlay(owner)


func _update_ash_visuals(owner: RealmView, island_rect: Rect2) -> void:
	var ash: float = owner.state.get_resource_amount(ResourceIds.ASH)
	owner.ash_visual_controller.update_realm_visuals(
		owner,
		owner.realm_layout,
		island_rect,
		ash,
		owner.size * owner.ISLAND_CENTER_RATIO,
		owner.ASH_VISUAL_RADIUS
	)


func _update_braziers(owner: RealmView, island_rect: Rect2) -> void:
	owner.brazier_visual_controller.update_stat_values(
		owner.braziers,
		owner.BRAZIER_STATS,
		owner.state.realm_configuration
	)
	owner.brazier_visual_controller.position_braziers(
		owner.braziers,
		owner.BRAZIER_STATS,
		owner.realm_layout,
		island_rect
	)


func _update_forge_visuals(owner: RealmView, island_rect: Rect2) -> void:
	var forge_position: Vector2 = owner._get_generator_position_in_rect(
		"infernal_forge",
		island_rect
	)
	owner.forge_activity_visual_controller.update(
		owner,
		owner.state.generators.get("infernal_forge"),
		forge_position
	)


func _update_layout_overlay(owner: RealmView) -> void:
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
		owner.BRAZIER_STATS,
		owner.realm_layout_editor_controller.drag_controller.dragging_object,
		owner.realm_layout,
		island_rect
	)
