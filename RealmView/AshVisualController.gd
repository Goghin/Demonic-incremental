class_name AshVisualController
extends RefCounted


var piles: Array[Sprite2D] = []
var pile_renderer: AshPileRenderer = AshPileRenderer.new()
var contamination_renderer: AshContaminationRenderer


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



func update_contamination(
	owner: Node,
	center: Vector2,
	width: float,
	ash: float
) -> void:
	if contamination_renderer == null:
		contamination_renderer = AshContaminationRenderer.new()
		contamination_renderer.attach_to(owner)

	contamination_renderer.update_visuals(center, width, ash)
