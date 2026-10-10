class_name AshPileRenderer
extends RefCounted


const ASH_PILE_TEXTURE: Texture2D = preload("res://RealmView/ashpile.png")
const ASH_PILE_BASE_WIDTH_RATIO: float = 0.018
const ASH_PILE_MAX_WIDTH_RATIO: float = 0.085
const ASH_PILE_FULL_GROWTH_ASH: float = 10000.0


func setup(
	view: Node2D,
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
	layout_positions: Array[Vector2],
	island_rect: Rect2,
	ash: float
) -> void:
	if piles.is_empty():
		return

	var texture_width: float = max(ASH_PILE_TEXTURE.get_size().x, 1.0)
	var growth: float = clamp(
		ash / ASH_PILE_FULL_GROWTH_ASH,
		0.0,
		1.0
	)

	for i in range(piles.size()):
		var pile: Sprite2D = piles[i]
		if not is_instance_valid(pile):
			continue

		var normalized_position: Vector2 = layout_positions[i]
		pile.position = island_rect.position + Vector2(
			island_rect.size.x * normalized_position.x,
			island_rect.size.y * normalized_position.y
		)
		pile.visible = ash > 0.0

		var individual_growth: float = 0.72 + float(i % 3) * 0.14
		var width_ratio: float = lerp(
			ASH_PILE_BASE_WIDTH_RATIO,
			ASH_PILE_MAX_WIDTH_RATIO,
			growth * individual_growth
		)
		var target_width: float = island_rect.size.x * width_ratio
		var uniform_scale: float = target_width / texture_width
		pile.scale = Vector2.ONE * uniform_scale
