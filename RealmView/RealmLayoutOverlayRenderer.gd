class_name RealmLayoutOverlayRenderer
extends Control


var generator_hitboxes: Dictionary = {}
var ash_piles: Array[Sprite2D] = []
var braziers: Dictionary = {}
var brazier_stats: Array[String] = []
var overlay_enabled: bool = false


func setup(view: Control) -> void:
	name = "RealmLayoutOverlayRenderer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.add_child(self)


func update_overlay(
	is_enabled: bool,
	new_generator_hitboxes: Dictionary,
	new_ash_piles: Array[Sprite2D],
	new_braziers: Dictionary,
	new_brazier_stats: Array[String]
) -> void:
	overlay_enabled = is_enabled
	generator_hitboxes = new_generator_hitboxes
	ash_piles = new_ash_piles
	braziers = new_braziers
	brazier_stats = new_brazier_stats
	queue_redraw()


func _draw() -> void:
	if not overlay_enabled:
		return

	draw_overlay(
		self,
		generator_hitboxes,
		ash_piles,
		braziers,
		brazier_stats
	)


func draw_overlay(
	owner: Control,
	generator_hitboxes: Dictionary,
	ash_piles: Array[Sprite2D],
	braziers: Dictionary,
	brazier_stats: Array[String]
) -> void:
	owner.draw_rect(
		Rect2(Vector2.ZERO, owner.size),
		Color(1.0, 0.75, 0.20, 0.65),
		false,
		2.0
	)

	# ------------------------------------------------------------
	# Generator selection boxes
	# ------------------------------------------------------------

	for generator_id in generator_hitboxes:
		var hitbox: Rect2 = generator_hitboxes[
			generator_id
		]

		owner.draw_rect(
			hitbox.grow(3.0),
			Color(1.0, 0.75, 0.20, 0.75),
			false,
			1.0
		)

	# ------------------------------------------------------------
	# Ash pile position markers
	# ------------------------------------------------------------

	for i in range(ash_piles.size()):
		var pile: Sprite2D = ash_piles[i]
		owner.draw_circle(
			pile.position,
			12.0,
			Color(0.75, 0.75, 0.75, 0.2)
		)
		owner.draw_circle(
			pile.position,
			14.0,
			Color(0.85, 0.75, 0.55, 0.85),
			false,
			2.0
		)
		owner.draw_string(
			ThemeDB.fallback_font,
			pile.position + Vector2(4.0, -7.0),
			"A%d" % (i + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12,
			Color(1.0, 0.9, 0.7, 1.0)
		)

	# ------------------------------------------------------------
	# Brazier selection markers
	# ------------------------------------------------------------

	for stat_name in brazier_stats:
		if not braziers.has(stat_name):
			continue

		var brazier: Control = braziers[stat_name]
		var brazier_position: Vector2 = brazier.position

		owner.draw_circle(
			brazier_position,
			30.0,
			Color(1.0, 0.75, 0.20, 0.15)
		)

		owner.draw_circle(
			brazier_position,
			32.0,
			Color(1.0, 0.75, 0.20, 0.75),
			false,
			2.0
		)

		owner.draw_line(
			brazier_position + Vector2(-42, 0),
			brazier_position + Vector2(42, 0),
			Color(1.0, 0.75, 0.20, 0.50),
			1.0
		)

		owner.draw_line(
			brazier_position + Vector2(0, -42),
			brazier_position + Vector2(0, 42),
			Color(1.0, 0.75, 0.20, 0.50),
			1.0
		)
