class_name ForgeLevelReductionEffect
extends Node2D


const DURATION: float = 0.78
const CYAN: Color = Color(0.26, 0.91, 0.96, 1.0)
const TEAL: Color = Color(0.20, 0.84, 0.70, 1.0)

var elapsed: float = 0.0
var particles: Array[Dictionary] = []


func _ready() -> void:
	z_index = 24
	for i in range(14):
		var angle := TAU * float(i) / 14.0 + randf_range(-0.16, 0.16)
		particles.append({
			"direction": Vector2(cos(angle), sin(angle)),
			"speed": randf_range(34.0, 82.0),
			"size": randf_range(1.2, 2.8),
			"phase": randf_range(0.0, TAU)
		})
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(elapsed / DURATION, 0.0, 1.0)
	var fade := 1.0 - progress
	var ring_radius := lerpf(9.0, 58.0, ease(progress, 0.65))

	# A sharp cyan inner ring with a softer teal halo reads as a distinct
	# mechanical consequence, even if the warm critical burst fires too.
	draw_arc(
		Vector2.ZERO,
		ring_radius,
		0.0,
		TAU,
		48,
		Color(TEAL.r, TEAL.g, TEAL.b, 0.20 * fade),
		7.0 * fade + 1.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		ring_radius,
		0.0,
		TAU,
		48,
		Color(CYAN.r, CYAN.g, CYAN.b, 0.92 * fade),
		2.0,
		true
	)
	draw_circle(
		Vector2.ZERO,
		lerpf(7.0, 2.0, progress),
		Color(CYAN.r, CYAN.g, CYAN.b, 0.20 * fade)
	)
	draw_circle(
		Vector2.ZERO,
		lerpf(3.5, 0.8, progress),
		Color(0.78, 1.0, 1.0, 0.95 * fade)
	)

	for particle in particles:
		var direction: Vector2 = particle["direction"]
		var distance: float = float(particle["speed"]) * elapsed
		var wobble := sin(elapsed * 18.0 + float(particle["phase"])) * 2.5
		var particle_position := direction * distance
		particle_position += direction.rotated(PI * 0.5) * wobble
		var size: float = float(particle["size"]) * fade
		if size <= 0.0:
			continue
		draw_line(
			particle_position - direction * size * 2.4,
			particle_position,
			Color(CYAN.r, CYAN.g, CYAN.b, 0.82 * fade),
			maxf(size * 0.7, 0.6),
			true
		)
		draw_circle(
			particle_position,
			size * 1.8,
			Color(TEAL.r, TEAL.g, TEAL.b, 0.20 * fade)
		)
		draw_circle(
			particle_position,
			size,
			Color(CYAN.r, CYAN.g, CYAN.b, 0.95 * fade)
		)
