class_name AshVisualController
extends RefCounted


var piles: Array[Sprite2D] = []
var pile_renderer: AshPileRenderer = AshPileRenderer.new()


func setup(
	owner: Control,
	realm_layout: RealmLayout
) -> void:
	piles = pile_renderer.setup(
		owner,
		piles,
		realm_layout
	)


func update_piles(
	realm_layout: RealmLayout,
	island_rect: Rect2,
	ash: float
) -> void:
	if realm_layout == null:
		return

	pile_renderer.update(
		piles,
		realm_layout.ash_pile_layout_positions,
		island_rect,
		ash
	)
