class_name MolecularAgitationParticleController
extends RefCounted


var overlay: MolecularAgitationParticleOverlay


func ensure_overlay(
	parent: Node,
	generator: Generator,
	overlay_position: Vector2
) -> void:
	if overlay == null or not is_instance_valid(overlay):
		overlay = MolecularAgitationParticleOverlay.new()
		overlay.name = "MolecularAgitationParticleOverlay"
		overlay.z_index = 11
		parent.add_child(overlay)

	update(generator, overlay_position)


func update(
	generator: Generator,
	overlay_position: Vector2
) -> void:
	if generator == null:
		hide()
		return

	if overlay == null or not is_instance_valid(overlay):
		return

	var should_be_active: bool = (
		generator.unlocked
		and generator.level > 0
		and generator.is_operating()
	)

	overlay.visible = should_be_active
	overlay.active = should_be_active
	overlay.generator_level = generator.level

	if should_be_active:
		overlay.position = overlay_position


func hide() -> void:
	if overlay == null or not is_instance_valid(overlay):
		return

	overlay.visible = false
	overlay.active = false


func reset() -> void:
	if overlay == null or not is_instance_valid(overlay):
		return

	overlay.active = false
	overlay.visible = false
	overlay.time = 0.0
