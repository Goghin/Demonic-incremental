class_name AshVisualController
extends RefCounted


var piles: Array[Sprite2D] = []
var pile_smoke_emitters: Array[SmokeEmitterRenderer] = []
var realm_view: RealmView
var pile_renderer: AshPileRenderer = AshPileRenderer.new()
var contamination_renderer: AshContaminationRenderer


func setup(
	owner: Control,
	realm_layout: RealmLayout
) -> void:
	realm_view = owner as RealmView
	_clear_pile_smoke_emitters()

	piles = pile_renderer.setup(
		owner,
		piles,
		realm_layout
	)

	for i in range(piles.size()):
		var emitter := SmokeEmitterRenderer.new()
		emitter.name = "AshPileSmoke_%02d" % (i + 1)
		emitter.z_index = 8
		owner.add_child(emitter)
		pile_smoke_emitters.append(emitter)


func update_piles(
	realm_layout: RealmLayout,
	island_rect: Rect2,
	ash: float
) -> void:
	if realm_layout == null:
		_hide_pile_smoke_emitters()
		return

	pile_renderer.update(
		piles,
		realm_layout.ash_pile_layout_positions,
		island_rect,
		ash
	)

	var texture_height: float = 1.0
	if not piles.is_empty() and piles[0].texture != null:
		texture_height = maxf(piles[0].texture.get_size().y, 1.0)
	var max_pile_scale: float = 1.0
	if not piles.is_empty() and piles[0].texture != null:
		max_pile_scale = island_rect.size.x * 0.085 / maxf(
			piles[0].texture.get_size().x,
			1.0
		)

	for i in range(pile_smoke_emitters.size()):
		var emitter: SmokeEmitterRenderer = pile_smoke_emitters[i]
		if not is_instance_valid(emitter):
			continue
		if i >= piles.size() or not is_instance_valid(piles[i]):
			emitter.visible = false
			emitter.set_process(false)
			continue

		var pile: Sprite2D = piles[i]
		var pile_has_position: bool = i < realm_layout.ash_pile_layout_positions.size()
		var effects_enabled: bool = realm_view != null and realm_view.visual_effects_enabled
		var enabled: bool = pile_has_position and pile.visible and effects_enabled
		if not enabled:
			emitter.visible = false
			emitter.set_process(false)
			continue

		# Anchor the column near the top of the pile so it looks like smoke
		# is rising from the Ash itself, rather than from the pile's center.
		var pile_top_offset: float = texture_height * pile.scale.y * 0.28
		emitter.position = pile.position + Vector2(0.0, -pile_top_offset)

		# Bigger piles produce a fuller, more visible column.
		var pile_growth: float = clampf(pile.scale.x / max_pile_scale, 0.0, 1.0)
		var smoke_size: float = lerpf(0.35, 0.82, pile_growth)
		var smoke_opacity: float = lerpf(0.18, 0.48, pile_growth)
		emitter.configure(
			smoke_size,
			0.1,
			smoke_opacity,
			"column",
			(i % 5) + 1
		)
		emitter.visible = true
		emitter.set_process(true)


func _hide_pile_smoke_emitters() -> void:
	for emitter in pile_smoke_emitters:
		if is_instance_valid(emitter):
			emitter.visible = false
			emitter.set_process(false)


func _clear_pile_smoke_emitters() -> void:
	for emitter in pile_smoke_emitters:
		if is_instance_valid(emitter):
			emitter.queue_free()
	pile_smoke_emitters.clear()


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


func update_realm_visuals(
	owner: Node,
	realm_layout: RealmLayout,
	island_rect: Rect2,
	ash: float,
	contamination_center: Vector2,
	contamination_width: float
) -> void:
	update_piles(realm_layout, island_rect, ash)
	update_contamination(
		owner,
		contamination_center,
		contamination_width,
		ash
	)
