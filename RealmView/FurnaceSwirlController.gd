class_name FurnaceSwirlController
extends RefCounted


var overlay: FurnaceSwirlOverlay


func update(
	parent: Node,
	generator: Generator,
	generator_sprite: Sprite2D,
	effect_quality: int = RealmView.VISUAL_EFFECT_MEDIUM
) -> void:
	if not generator_sprite.visible:
		if overlay != null and is_instance_valid(overlay):
			if overlay.visible:
				overlay.visible = false
			if overlay.active:
				overlay.active = false
		return

	if overlay == null or not is_instance_valid(overlay):
		overlay = FurnaceSwirlOverlay.new()
		overlay.name = "FurnaceSwirlOverlay"
		overlay.z_index = 14
		parent.add_child(overlay)

	var target_operating: bool = generator.is_operating()
	if overlay.position != generator_sprite.position:
		overlay.position = generator_sprite.position
	if overlay.visible != target_operating:
		overlay.visible = target_operating
	if overlay.active != target_operating:
		overlay.active = target_operating
	if overlay.effect_quality != effect_quality:
		overlay.effect_quality = effect_quality

	var target_speed_multiplier: float = (
		1.0 +
		max(generator.level - 1, 0) * 0.03
	)
	if not is_equal_approx(overlay.speed_multiplier, target_speed_multiplier):
		overlay.speed_multiplier = target_speed_multiplier


func reset() -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.visible = false
		overlay.active = false
