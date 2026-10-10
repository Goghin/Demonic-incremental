class_name FurnaceSwirlController
extends RefCounted


var overlay: FurnaceSwirlOverlay


func update(
	parent: Node,
	generator: Generator,
	generator_sprite: Sprite2D
) -> void:
	if not generator_sprite.visible:
		if overlay != null and is_instance_valid(overlay):
			overlay.visible = false
		return

	if overlay == null or not is_instance_valid(overlay):
		overlay = FurnaceSwirlOverlay.new()
		overlay.name = "FurnaceSwirlOverlay"
		overlay.z_index = 14
		parent.add_child(overlay)

	overlay.position = generator_sprite.position
	overlay.visible = generator.is_operating()
	overlay.active = generator.is_operating()
	overlay.speed_multiplier = (
		1.0 +
		max(generator.level - 1, 0) * 0.03
	)


func reset() -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.visible = false
