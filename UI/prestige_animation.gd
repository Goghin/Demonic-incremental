class_name PrestigeAnimation
extends Control


signal destruction_complete
signal animation_finished


var is_playing: bool = false

var realm_view: RealmView
var realm_original_position: Vector2 = Vector2.ZERO

var explosion_active: bool = false
var explosion_progress: float = 0.0
var explosion_center: Vector2 = Vector2.ZERO


@onready var flash: ColorRect = $Flash
@onready var void_overlay: ColorRect = $VoidOverlay


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	flash.color = Color(
		1.0,
		0.45,
		0.05,
		0.0
	)

	void_overlay.color = Color(
		0.0,
		0.0,
		0.0,
		0.0
	)

	visible = false


func setup(target_realm_view: RealmView) -> void:
	realm_view = target_realm_view


func play() -> void:
	if is_playing:
		return

	is_playing = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	flash.color.a = 0.0
	void_overlay.color.a = 0.0

	explosion_active = false
	explosion_progress = 0.0

	if realm_view != null:
		realm_original_position = realm_view.position

		explosion_center = realm_view.to_global(
			realm_view.core_layout_position
		)

		realm_view.begin_prestige_destruction()

	await get_tree().create_timer(0.85).timeout

	# --------------------------------
	# First flash
	# --------------------------------

	var flash_tween := create_tween()

	flash_tween.tween_property(
		flash,
		"color:a",
		0.70,
		0.08
	)

	flash_tween.tween_property(
		flash,
		"color:a",
		0.0,
		0.20
	)

	# --------------------------------
	# Massive realm explosion
	# --------------------------------

	explosion_active = true
	explosion_progress = 0.0
	queue_redraw()

	var explosion_tween := create_tween()

	explosion_tween.tween_method(
		_set_explosion_progress,
		0.0,
		1.0,
		0.65
	)

	await explosion_tween.finished

	explosion_active = false
	explosion_progress = 0.0

	if realm_view != null:
		realm_view.position = realm_original_position

	queue_redraw()

	# --------------------------------
	# Realm disappears into the void
	# --------------------------------

	var void_tween := create_tween()

	void_tween.tween_property(
		void_overlay,
		"color:a",
		1.0,
		0.40
	)

	await void_tween.finished

	# IMPORTANT:
	# The actual prestige reset happens here.
	destruction_complete.emit()

	await get_tree().create_timer(0.20).timeout

	# --------------------------------
	# Rebirth
	# --------------------------------

	var rebirth_tween := create_tween()

	rebirth_tween.tween_property(
		void_overlay,
		"color:a",
		0.0,
		1.50
	)

	await rebirth_tween.finished

	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_playing = false

	animation_finished.emit()


func _set_explosion_progress(value: float) -> void:
	explosion_progress = value

	if realm_view != null:
		var strength: float = (
			1.0 - explosion_progress
		) * 10.0

		realm_view.position = (
			realm_original_position
			+ Vector2(
				randf_range(-strength, strength),
				randf_range(-strength, strength)
			)
		)

	queue_redraw()


func _draw() -> void:
	if not explosion_active:
		return

	var p: float = explosion_progress

	# Fast initial expansion, slower at the end.
	var expansion: float = (
		1.0
		- pow(1.0 - p, 2.0)
	)

	var max_radius: float = (
		max(size.x, size.y) * 0.75
	)

	var radius: float = lerp(
		15.0,
		max_radius,
		expansion
	)

	# --------------------------------
	# Main shockwave
	# --------------------------------

	var ring_alpha: float = (
		1.0 - p
	)

	draw_arc(
		explosion_center,
		radius,
		0.0,
		TAU,
		64,
		Color(
			1.0,
			0.30,
			0.03,
			ring_alpha * 0.85
		),
		10.0,
		true
	)

	draw_arc(
		explosion_center,
		radius * 0.78,
		0.0,
		TAU,
		64,
		Color(
			1.0,
			0.75,
			0.20,
			ring_alpha * 0.50
		),
		4.0,
		true
	)

	# --------------------------------
	# Central explosion
	# --------------------------------

	var core_radius: float = lerp(
		18.0,
		130.0,
		expansion
	)

	var core_alpha: float = (
		1.0 - p
	) * 0.55

	draw_circle(
		explosion_center,
		core_radius,
		Color(
			1.0,
			0.30,
			0.02,
			core_alpha
		)
	)

	draw_circle(
		explosion_center,
		core_radius * 0.45,
		Color(
			1.0,
			0.85,
			0.45,
			core_alpha * 1.5
		)
	)

	# --------------------------------
	# Radial energy fragments
	# --------------------------------

	const RAY_COUNT: int = 24

	for i in range(RAY_COUNT):
		var angle: float = (
			float(i) * TAU / float(RAY_COUNT)
			+ sin(float(i) * 17.3) * 0.12
		)

		var direction := Vector2(
			cos(angle),
			sin(angle)
		)

		var start_distance: float = (
			radius * 0.18
		)

		var length_multiplier: float = (
			0.65
			+ abs(sin(float(i) * 8.7)) * 0.55
		)

		var end_distance: float = (
			radius * length_multiplier
		)

		draw_line(
			explosion_center
			+ direction * start_distance,
			explosion_center
			+ direction * end_distance,
			Color(
				1.0,
				0.45,
				0.05,
				ring_alpha * 0.70
			),
			3.0,
			true
		)
