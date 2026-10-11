class_name RealmSetupController
extends RefCounted


func setup(owner: RealmView, game_state: GameState) -> void:
	owner.state = game_state

	_setup_generator_layer(owner)
	_apply_realm_transform(owner)
	_setup_realm_overlays(owner)
	owner.rebuild_realm(owner.state.realm_layout)


func _setup_generator_layer(owner: RealmView) -> void:
	owner.generator_layer = owner.generator_visual_renderer.setup_layer(
		owner,
		owner.generator_layer
	)


func _apply_realm_transform(owner: RealmView) -> void:
	owner.scale = Vector2(
		owner.REALM_VISUAL_SCALE,
		owner.REALM_VISUAL_SCALE
	)
	owner.pivot_offset = owner.size * 0.5
	owner.position = owner.REALM_VISUAL_OFFSET


func _setup_realm_overlays(owner: RealmView) -> void:
	owner.brazier_visual_controller.setup(
		owner,
		owner.braziers,
		owner.BRAZIER_STATS,
		owner.BRAZIER_SCENE
	)
	owner.realm_layout_overlay_renderer.setup(owner)
