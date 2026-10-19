class_name SmokeVisualController
extends RefCounted


var emitters: Array[SmokeEmitterRenderer] = []


func update(owner: RealmView, island_rect: Rect2) -> void:
	var layout: RealmLayout = owner.realm_layout
	if layout == null:
		_clear_emitters()
		return

	while emitters.size() > layout.smoke_emitter_definitions.size():
		var removed: SmokeEmitterRenderer = emitters.pop_back()
		if is_instance_valid(removed):
			removed.queue_free()

	while emitters.size() < layout.smoke_emitter_definitions.size():
		var emitter := SmokeEmitterRenderer.new()
		emitter.name = "SmokeEmitter%d" % (emitters.size() + 1)
		emitter.z_index = 15
		owner.add_child(emitter)
		emitters.append(emitter)

	for index in range(layout.smoke_emitter_definitions.size()):
		var definition: Dictionary = layout.smoke_emitter_definitions[index]
		var emitter: SmokeEmitterRenderer = emitters[index]
		if not is_instance_valid(emitter):
			continue

		var normalized_position: Vector2 = definition.get("position", Vector2(0.5, 0.5))
		emitter.position = island_rect.position + island_rect.size * normalized_position
		var quality_multiplier: float = _get_quality_multiplier(owner.visual_effect_quality)
		emitter.configure(
			float(definition.get("size", 1.0)),
			float(definition.get("emission_rate", 1.0)) * quality_multiplier,
			float(definition.get("opacity", 0.7)),
			str(definition.get("style", "puff")),
			int(definition.get("variant", 1))
		)
		emitter.visible = owner.visual_effects_enabled
		emitter.set_process(owner.visual_effects_enabled)


func _clear_emitters() -> void:
	for emitter in emitters:
		if is_instance_valid(emitter):
			emitter.queue_free()
	emitters.clear()


func _get_quality_multiplier(quality: int) -> float:
	match quality:
		RealmView.VISUAL_EFFECT_LOW:
			return 0.5
		RealmView.VISUAL_EFFECT_HIGH:
			return 1.5
		_:
			return 1.0
