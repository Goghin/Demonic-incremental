class_name ThermalFurnaceAnimationController
extends RefCounted


const ROTATION_SPEED: float = 1.0

var inner_sprite: Sprite2D


func update(
	parent: Node,
	generator: Generator,
	sprite: Sprite2D,
	delta: float
) -> void:
	if not sprite.visible:
		if inner_sprite != null:
			inner_sprite.visible = false
		return

	if not generator.is_operating():
		if inner_sprite != null:
			inner_sprite.visible = false
		return

	var level_speed_multiplier: float = (
		1.0 +
		max(generator.level - 1, 0) * 0.05
	)

	var rotation_speed: float = (
		ROTATION_SPEED *
		level_speed_multiplier
	)

	sprite.rotation += rotation_speed * delta

	if inner_sprite == null:
		inner_sprite = Sprite2D.new()
		inner_sprite.name = "ThermalFurnaceSecondSwirl"
		inner_sprite.z_index = 11
		parent.add_child(inner_sprite)

	inner_sprite.texture = sprite.texture
	inner_sprite.visible = true
	inner_sprite.position = sprite.position
	inner_sprite.scale = sprite.scale
	inner_sprite.modulate = Color(
		1.0,
		1.0,
		1.0,
		0.75
	)

	# Same-size secondary layer, rotating a little faster.
	inner_sprite.rotation += rotation_speed * 1.2 * delta


func reset() -> void:
	if inner_sprite == null:
		return

	inner_sprite.visible = false
	inner_sprite.rotation = 0.0
