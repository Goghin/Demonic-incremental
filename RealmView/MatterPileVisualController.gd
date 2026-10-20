class_name MatterPileVisualController
extends RefCounted


var piles: Array[Node2D] = []
var pile_renderer: MatterPileRenderer = MatterPileRenderer.new()


func setup(owner: Control, realm_layout: RealmLayout) -> void:
	piles = pile_renderer.setup(owner, piles, realm_layout)


func update_piles(
	realm_layout: RealmLayout,
	island_rect: Rect2,
	matter: float
) -> void:
	if realm_layout == null:
		return

	pile_renderer.update(
		piles,
		realm_layout.matter_pile_layout_positions,
		realm_layout.matter_pile_layout_rotations,
		island_rect,
		matter
	)
