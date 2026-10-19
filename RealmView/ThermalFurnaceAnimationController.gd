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
	if not sprite.visible or not generator.is_operating():
		_hide_inner_sprite()
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

	if inner_sprite.texture != sprite.texture:
		inner_sprite.texture = sprite.texture
	if not inner_sprite.visible:
		inner_sprite.visible = true
	if inner_sprite.position != sprite.position:
		inner_sprite.position = sprite.position
	if inner_sprite.scale != sprite.scale:
		inner_sprite.scale = sprite.scale
	var target_modulate: Color = Color(1.0, 1.0, 1.0, 0.75)
	if inner_sprite.modulate != target_modulate:
		inner_sprite.modulate = target_modulate

	# Same-size secondary layer, rotating a little faster.
	inner_sprite.rotation += rotation_speed * 1.2 * delta


func reset() -> void:
	if inner_sprite == null:
		return

	_hide_inner_sprite()
	if inner_sprite.rotation != 0.0:
		inner_sprite.rotation = 0.0


func _hide_inner_sprite() -> void:
	if inner_sprite != null and inner_sprite.visible:
		inner_sprite.visible = false
