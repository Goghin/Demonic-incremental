
class_name PrestigeAnimation
extends Control


signal destruction_complete
signal animation_finished


var is_playing: bool = false

var realm_view: RealmView
var realm_original_position: Vector2 = Vector2.ZERO


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

	if realm_view != null:
		realm_original_position = realm_view.position

		# Each crystallized flame handles its own
		# destruction and explosion at its own position.
		realm_view.begin_prestige_destruction()

	await get_tree().create_timer(3.2).timeout

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

	await flash_tween.finished

	# --------------------------------
	# Realm shake
	# --------------------------------

	var shake_tween := create_tween()

	shake_tween.tween_method(
		_shake_realm,
		0.0,
		1.0,
		0.65
	)

	await shake_tween.finished

	if realm_view != null:
		realm_view.position = realm_original_position

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

	await get_tree().create_timer(1.4).timeout

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


func _shake_realm(value: float) -> void:
	if realm_view == null:
		return

	var strength: float = (
		1.0 - value
	) * 10.0

	realm_view.position = (
		realm_original_position
		+ Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
	)
