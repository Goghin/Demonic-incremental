class_name RealmRebuildStateController
extends RefCounted


func refresh(owner: Control) -> void:
	# Recreate crystal visuals after generator and realm geometry are ready.
	owner.crystallized_flame_visual_controller.reset_and_update(
		owner,
		owner.state
	)

	# Lake fill must be refreshed before dependent lava flow states.
	owner.lava_realm_visual_controller.update_dynamic_states(
		owner.state,
		owner.realm_layout
	)
