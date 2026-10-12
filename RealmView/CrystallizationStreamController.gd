class_name CrystallizationStreamController
extends RefCounted


func play_crystallization_event(
	owner: Control,
	crystals_created: float,
	forge_position: Vector2,
	crystals: Array[CrystallizedFlame],
	crystal_values: Array[float],
	total_flames: float,
	crystal_renderer: CrystalRenderer
) -> void:
	if crystals_created <= 0.0:
		return

	var old_count: int = crystals.size()
	crystal_renderer.update(
		owner,
		crystals,
		crystal_values,
		total_flames
	)

	# A completion always releases a short radial burst from the forge,
	# even when the visible crystal count is already at its cap.
	play_burst(owner, forge_position)

	var new_count: int = crystals.size()
	if new_count > old_count:
		for i in range(old_count, new_count):
			var crystal: CrystallizedFlame = crystals[i]
			play(
				owner,
				forge_position,
				crystal.base_position,
				crystal,
				CrystalRenderer.CRYSTAL_BASE_SCALE
			)
		return

	# When no new crystal can be added, stream the energy into a few
	# existing crystals and pulse them to suggest that they are growing.
	var candidates: Array[CrystallizedFlame] = []
	for crystal in crystals:
		if is_instance_valid(crystal) and not crystal.destruction_active:
			candidates.append(crystal)

	var target_count: int = min(
		candidates.size(),
		clampi(roundi(crystals_created), 1, 3)
	)

	for i in range(target_count):
		var candidate_index: int = randi_range(0, candidates.size() - 1)
		var crystal: CrystallizedFlame = candidates.pop_at(candidate_index)
		play_growth_stream(
			owner,
			forge_position,
			crystal.base_position,
			crystal
		)


func play(
	owner: Node,
	from_position: Vector2,
	target_position: Vector2,
	crystal: CrystallizedFlame,
	crystal_base_scale: float
) -> void:
	var stream := CrystallizationStream.new()

	stream.setup(
		from_position,
		target_position
	)

	stream.z_index = 20

	owner.add_child(stream)

	crystal.scale = Vector2.ZERO

	var target_scale := Vector2(
		crystal_base_scale,
		crystal_base_scale
	)

	var formation_delay := (
		stream.duration * 0.72
	)

	var tween := owner.create_tween()

	tween.tween_interval(
		formation_delay
	)

	tween.tween_property(
		crystal,
		"scale",
		target_scale * 0.18,
		0.10
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		crystal,
		"scale",
		target_scale * 1.18,
		0.24
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		crystal,
		"scale",
		target_scale,
		0.18
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN_OUT
	)



func play_burst(owner: Node, position: Vector2) -> void:
	var burst := CrystallizationStream.new()
	burst.setup_burst(position)
	burst.z_index = 22
	owner.add_child(burst)


func play_growth_stream(
	owner: Node,
	from_position: Vector2,
	target_position: Vector2,
	crystal: CrystallizedFlame
) -> void:
	var stream := CrystallizationStream.new()
	stream.setup(from_position, target_position)
	stream.z_index = 20
	owner.add_child(stream)

	var target_scale: Vector2 = crystal.scale
	var tween := owner.create_tween()
	tween.tween_interval(stream.duration * 0.72)
	tween.tween_property(
		crystal,
		"scale",
		target_scale * 1.32,
		0.14
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		crystal,
		"scale",
		target_scale,
		0.22
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
