class_name MolecularAgitationParticleController
extends RefCounted


var overlay: MolecularAgitationParticleOverlay


func ensure_overlay(
	parent: Node,
	generator: Generator,
	overlay_position: Vector2,
	effect_quality: int = RealmView.VISUAL_EFFECT_MEDIUM
) -> void:
	if overlay == null or not is_instance_valid(overlay):
		overlay = MolecularAgitationParticleOverlay.new()
		overlay.name = "MolecularAgitationParticleOverlay"
		overlay.z_index = 11
		parent.add_child(overlay)

	update(generator, overlay_position, effect_quality)


func update(
	generator: Generator,
	overlay_position: Vector2,
	effect_quality: int = RealmView.VISUAL_EFFECT_MEDIUM
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

	if overlay.visible != should_be_active:
		overlay.visible = should_be_active
	if overlay.active != should_be_active:
		overlay.active = should_be_active
	if overlay.generator_level != generator.level:
		overlay.generator_level = generator.level
	if overlay.effect_quality != effect_quality:
		overlay.effect_quality = effect_quality

	if should_be_active and overlay.position != overlay_position:
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
