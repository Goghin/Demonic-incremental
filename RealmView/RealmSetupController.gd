class_name RealmSetupController
extends RefCounted


func setup(owner: Control, game_state: GameState) -> void:
	owner.state = game_state
	owner.generator_layer = owner.generator_visual_renderer.setup_layer(
		owner,
		owner.generator_layer
	)

	owner.scale = Vector2(
		owner.REALM_VISUAL_SCALE,
		owner.REALM_VISUAL_SCALE
	)

	owner.pivot_offset = owner.size * 0.5
	owner.position = owner.REALM_VISUAL_OFFSET

	owner.brazier_visual_controller.setup(
		owner,
		owner.braziers,
		owner.BRAZIER_STATS,
		owner.BRAZIER_SCENE
	)
	owner.realm_layout_overlay_renderer.setup(owner)

	owner.rebuild_realm(owner.state.realm_layout)
