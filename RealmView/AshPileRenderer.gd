class_name AshPileRenderer
extends RefCounted


const ASH_PILE_TEXTURE: Texture2D = preload("res://RealmView/ashpile.png")
const ASH_PILE_BASE_WIDTH_RATIO: float = 0.006
const ASH_PILE_MAX_WIDTH_RATIO: float = 0.085
const ASH_PER_PILE_MAGNITUDE: float = 100.0
const GROWTH_CURVE_POWER: float = 0.68


func setup(
	view: Control,
	old_piles: Array[Sprite2D],
	layout: RealmLayout
) -> Array[Sprite2D]:
	for pile in old_piles:
		if is_instance_valid(pile):
			pile.queue_free()
	old_piles.clear()

	if layout == null:
		return old_piles

	for i in range(layout.ash_pile_layout_positions.size()):
		var pile: Sprite2D = Sprite2D.new()
		pile.name = "AshPile_%02d" % (i + 1)
		pile.texture = ASH_PILE_TEXTURE
		pile.centered = true
		pile.z_index = 7
		pile.visible = false
		view.add_child(pile)
		old_piles.append(pile)

	return old_piles


func update(
	piles: Array[Sprite2D],
	layout_positions: PackedVector2Array,
	island_rect: Rect2,
	ash: float
) -> void:
	if piles.is_empty():
		return

	var texture_width: float = max(ASH_PILE_TEXTURE.get_size().x, 1.0)
	var total_progress: float = _get_total_pile_progress(ash)

	for i in range(piles.size()):
		var pile: Sprite2D = piles[i]
		if not is_instance_valid(pile):
			continue
		if i >= layout_positions.size():
			pile.visible = false
			continue

		var normalized_position: Vector2 = layout_positions[i]
		pile.position = island_rect.position + Vector2(
			island_rect.size.x * normalized_position.x,
			island_rect.size.y * normalized_position.y
		)

		var individual_progress: float = clamp(total_progress - float(i), 0.0, 1.0)
		pile.visible = individual_progress > 0.0
		if not pile.visible:
			continue

		var curved_growth: float = pow(individual_progress, GROWTH_CURVE_POWER)
		var width_ratio: float = lerp(
			ASH_PILE_BASE_WIDTH_RATIO,
			ASH_PILE_MAX_WIDTH_RATIO,
			curved_growth
		)
		var pile_variation: float = 1.0 + float(i % 3 - 1) * 0.045
		var target_width: float = island_rect.size.x * width_ratio * pile_variation
		var uniform_scale: float = target_width / texture_width
		pile.scale = Vector2.ONE * uniform_scale


func _get_total_pile_progress(ash: float) -> float:
	if ash <= 0.0:
		return 0.0
	# 0–100 Ash builds the first pile, 100–10,000 builds the second, etc.
	# Log scaling keeps later runs from instantly maxing every pile.
	return log(1.0 + ash) / log(1.0 + ASH_PER_PILE_MAGNITUDE)
