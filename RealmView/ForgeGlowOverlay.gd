class_name ForgeGlowOverlay
extends Node2D

var glow_radius: float = 0.0
var glow_alpha: float = 0.0
var pulse: float = 0.0
var core_alpha: float = 1.0

func _draw() -> void:
	draw_circle(
		Vector2.ZERO,
		glow_radius,
		Color(
			1.0,
			0.25,
			0.02,
			glow_alpha
		)
	)

	draw_circle(
		Vector2.ZERO,
		glow_radius * 0.35,
		Color(
			1.0,
			0.55,
			0.08,
			glow_alpha * 1.5
		)
	)

	draw_circle(
		Vector2.ZERO,
		1.0 + pulse * 3.0,
		Color(
			1.0,
			0.85,
			0.35,
			core_alpha
		)
	)

