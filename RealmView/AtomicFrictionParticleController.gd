class_name AtomicFrictionParticleController
extends RefCounted


var overlay: AtomicFrictionParticleOverlay


func update(
	parent: Node,
	generator: Generator,
	generator_sprite: Sprite2D,
	effect_quality: int = RealmView.VISUAL_EFFECT_MEDIUM
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

	if should_be_active and overlay.position != generator_sprite.position:
		overlay.position = generator_sprite.position
	if overlay.visible != should_be_active:
		overlay.visible = should_be_active
	if overlay.active != should_be_active:
		overlay.active = should_be_active
	if overlay.generator_level != generator.level:
		overlay.generator_level = generator.level
	if overlay.operation_mode_id != generator.operation_mode_id:
		overlay.operation_mode_id = generator.operation_mode_id
	if overlay.effect_quality != effect_quality:
		overlay.effect_quality = effect_quality


func reset() -> void:
	if overlay == null or not is_instance_valid(overlay):
		return

	if overlay.active:
		overlay.active = false
	if overlay.visible:
		overlay.visible = false
	if overlay.time != 0.0:
		overlay.time = 0.0
