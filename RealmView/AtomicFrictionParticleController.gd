class_name AtomicFrictionParticleController
extends RefCounted


var overlay: AtomicFrictionParticleOverlay


func update(
	parent: Node,
	generator: Generator,
	generator_sprite: Sprite2D
) -> void:
	if overlay == null or not is_instance_valid(overlay):
		overlay = AtomicFrictionParticleOverlay.new()
		overlay.name = "AtomicFrictionParticleOverlay"
		overlay.z_index = 11
		parent.add_child(overlay)

	var should_be_active: bool = (
		generator_sprite.visible
		and generator.is_operating()
	)

	overlay.position = generator_sprite.position
	overlay.visible = should_be_active
	overlay.active = should_be_active
	overlay.generator_level = generator.level


func reset() -> void:
	if overlay == null or not is_instance_valid(overlay):
		return

	overlay.active = false
	overlay.visible = false
	overlay.time = 0.0
