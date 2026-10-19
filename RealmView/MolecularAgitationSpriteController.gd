class_name MolecularAgitationSpriteController
extends RefCounted


const ROTATION_SPEED: float = 1.0

var extra_sprite_a: Sprite2D
var extra_sprite_b: Sprite2D


func update(
	parent: Node,
	generator: Generator,
	sprite: Sprite2D,
	delta: float
) -> void:
	if generator == null or not sprite.visible or not generator.is_operating():
		hide()
		return

	if extra_sprite_a == null:
		extra_sprite_a = Sprite2D.new()
		extra_sprite_a.name = "MolecularAgitationSwirlA"
		extra_sprite_a.z_index = 12
		parent.add_child(extra_sprite_a)

	if extra_sprite_b == null:
		extra_sprite_b = Sprite2D.new()
		extra_sprite_b.name = "MolecularAgitationSwirlB"
		extra_sprite_b.z_index = 13
		parent.add_child(extra_sprite_b)

	var level_speed_multiplier: float = (
		1.0 + max(generator.level - 1, 0) * 0.05
	)

	_update_extra_sprite(extra_sprite_a, sprite)
	_update_extra_sprite(extra_sprite_b, sprite)

	# Positive rotation is clockwise in Godot's 2D coordinate system.
	extra_sprite_a.rotation += (
		ROTATION_SPEED
		* level_speed_multiplier
		* 0.82
		* delta
	)
	extra_sprite_b.rotation += (
		ROTATION_SPEED
		* level_speed_multiplier
		* 1.07
		* delta
	)


func hide() -> void:
	if extra_sprite_a != null and extra_sprite_a.visible:
		extra_sprite_a.visible = false
	if extra_sprite_b != null and extra_sprite_b.visible:
		extra_sprite_b.visible = false


func _update_extra_sprite(extra_sprite: Sprite2D, source_sprite: Sprite2D) -> void:
	if extra_sprite.texture != source_sprite.texture:
		extra_sprite.texture = source_sprite.texture
	if not extra_sprite.visible:
		extra_sprite.visible = true
	if extra_sprite.position != source_sprite.position:
		extra_sprite.position = source_sprite.position
	if extra_sprite.scale != source_sprite.scale:
		extra_sprite.scale = source_sprite.scale
	var target_modulate: Color = Color(1.0, 1.0, 1.0, 0.8)
	if extra_sprite.modulate != target_modulate:
		extra_sprite.modulate = target_modulate