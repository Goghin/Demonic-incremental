class_name GeneratorAshSmokeController
extends RefCounted


const ASH_PRODUCING_GENERATORS: Array[String] = [
	"thermal_furnace",
	"matter_furnace",
	"infernal_forge"
]
const EMITTERS_PER_GENERATOR: int = 3
const EMITTER_OFFSETS: Array[Vector2] = [
	Vector2(-0.32, -0.22),
	Vector2(0.0, -0.34),
	Vector2(0.32, -0.22)
]

var emitters_by_generator: Dictionary = {}


func update(owner: RealmView, island_rect: Rect2) -> void:
	var state: GameState = owner.state
	if state == null:
		_clear_all()
		return

	for generator_id in ASH_PRODUCING_GENERATORS:
		var generator: Generator = state.generators.get(generator_id)
		if generator == null or owner.realm_layout == null:
			_clear_generator(generator_id)
			continue

		if not owner.realm_layout.generator_layout_positions.has(generator_id):
			_clear_generator(generator_id)
			continue

		var emitters: Array = _ensure_emitters(owner, generator_id)
		var generator_position: Vector2 = owner._get_generator_position_in_rect(
			generator_id,
			island_rect
		)
		var machine_size: float = _get_machine_size(generator_id, island_rect)
		var ash_rate: float = _get_ash_output_rate(generator, state)
		var active: bool = generator.unlocked and generator.level > 0 and generator.is_operating()
		var intensity: float = clampf(ash_rate / 8.0, 0.0, 1.0) if active else 0.0
		var enabled: bool = owner.visual_effects_enabled and active and ash_rate > 0.0

		for index in range(emitters.size()):
			var emitter: SmokeEmitterRenderer = emitters[index]
			if not is_instance_valid(emitter):
				continue

			var offset: Vector2 = EMITTER_OFFSETS[index]
			emitter.position = generator_position + Vector2(
				offset.x * machine_size,
				offset.y * machine_size
			)
			emitter.configure(
				0.45 + intensity * 0.5,
				0.1 + intensity * 1.7,
				0.12 + intensity * 0.36,
				"puff"
			)
			emitter.visible = enabled
			emitter.set_process(enabled)


func _get_ash_output_rate(generator: Generator, state: GameState) -> float:
	var rate: float = 0.0
	for output in generator.get_active_outputs():
		if output.resource_id != ResourceIds.ASH or not output.unlocked:
			continue
		rate += generator.get_production_rate(output, state)
	return rate


func _ensure_emitters(owner: RealmView, generator_id: String) -> Array:
	var emitters: Array = emitters_by_generator.get(generator_id, [])
	while emitters.size() < EMITTERS_PER_GENERATOR:
		var emitter := SmokeEmitterRenderer.new()
		emitter.name = "%s_AshSmoke_%d" % [generator_id, emitters.size() + 1]
		emitter.z_index = 15
		owner.add_child(emitter)
		emitters.append(emitter)
	emitters_by_generator[generator_id] = emitters
	return emitters


func _get_machine_size(generator_id: String, island_rect: Rect2) -> float:
	var base: float = minf(island_rect.size.x, island_rect.size.y) * 0.10
	if generator_id == "infernal_forge":
		base *= 1.8
	return base


func _clear_generator(generator_id: String) -> void:
	var emitters: Array = emitters_by_generator.get(generator_id, [])
	for emitter in emitters:
		if is_instance_valid(emitter):
			emitter.queue_free()
	emitters_by_generator.erase(generator_id)


func _clear_all() -> void:
	for generator_id in emitters_by_generator.keys():
		_clear_generator(str(generator_id))
