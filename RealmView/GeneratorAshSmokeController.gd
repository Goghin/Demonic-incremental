class_name GeneratorAshSmokeController
extends RefCounted


const ASH_PRODUCING_GENERATORS: Array[String] = [
	"molecular_agitation",
	"thermal_furnace",
	"matter_furnace",
	"infernal_forge"
]
const EMITTERS_PER_GENERATOR: int = 3
# Activation order: middle first, then left, then right.
const EMITTER_STAGE_ORDER: Array[int] = [1, 0, 2]
const MAX_NORMALIZED_ASH_OUTPUT: float = 1.0
const EMITTER_SIZE_MIN: Array[float] = [0.32, 0.28, 0.24]
const EMITTER_SIZE_MAX: Array[float] = [0.88, 1.18, 0.76]
const EMITTER_RATE_MIN: Array[float] = [0.12, 0.10, 0.08]
const EMITTER_RATE_MAX: Array[float] = [1.00, 1.25, 0.78]
const EMITTER_OPACITY_MIN: Array[float] = [0.10, 0.08, 0.07]
const EMITTER_OPACITY_MAX: Array[float] = [0.44, 0.52, 0.36]

# Ash output rate at which each generator reaches the end of stage 3.
# Tune these independently to match each generator's expected production range.
const ASH_OUTPUT_TARGET_BY_GENERATOR: Dictionary = {
	"molecular_agitation": 8.0,
	"thermal_furnace": 8.0,
	"matter_furnace": 8.0,
	"infernal_forge": 8.0
}

# Offsets are normalized to each machine's visual size. Tune these per sprite.
const EMITTER_OFFSETS_BY_GENERATOR: Dictionary = {
	"molecular_agitation": [
		Vector2(-0.12, -0.10),
		Vector2(0.0, -0.18),
		Vector2(0.12, -0.10)
	],
	"thermal_furnace": [
		Vector2(-0.12, -0.10),
		Vector2(0.0, -0.18),
		Vector2(0.12, -0.10)
	],
	"matter_furnace": [
		Vector2(-0.32, -0.22),
		Vector2(0.0, -0.34),
		Vector2(0.32, -0.22)
	],
	"infernal_forge": [
		Vector2(-0.32, -0.22),
		Vector2(0.0, -0.34),
		Vector2(0.32, -0.22)
	]
}

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
		var enabled: bool = owner.visual_effects_enabled and active and ash_rate > 0.0
		var target_rate: float = maxf(
			float(ASH_OUTPUT_TARGET_BY_GENERATOR.get(generator_id, 8.0)),
			0.001
		)
		var normalized_output: float = clampf(
			ash_rate / target_rate,
			0.0,
			MAX_NORMALIZED_ASH_OUTPUT
		) if active else 0.0

		for index in range(emitters.size()):
			var emitter: SmokeEmitterRenderer = emitters[index]
			if not is_instance_valid(emitter):
				continue

			var offsets: Array = EMITTER_OFFSETS_BY_GENERATOR.get(generator_id, [])
			if index >= offsets.size():
				continue

			var offset: Vector2 = offsets[index]
			emitter.position = generator_position + Vector2(
				offset.x * machine_size,
				offset.y * machine_size
			)

			# Activate the middle plume first, then the left, then the right.
			# Every active emitter keeps growing as total Ash output rises;
			# later emitters do not stop the middle plume from growing.
			var stage: int = EMITTER_STAGE_ORDER.find(index)
			var stage_start: float = float(stage) / float(EMITTERS_PER_GENERATOR)
			var stage_progress: float = clampf(
				(normalized_output - stage_start) / (1.0 - stage_start),
				0.0,
				1.0
			)
			var stage_active: bool = enabled and normalized_output > stage_start
			var size: float = lerpf(
				EMITTER_SIZE_MIN[index],
				EMITTER_SIZE_MAX[index],
				stage_progress
			)
			var rate: float = lerpf(
				EMITTER_RATE_MIN[index],
				EMITTER_RATE_MAX[index],
				stage_progress
			)
			var opacity: float = lerpf(
				EMITTER_OPACITY_MIN[index],
				EMITTER_OPACITY_MAX[index],
				stage_progress
			)

			emitter.configure(size, rate, opacity, "puff")
			emitter.visible = stage_active
			emitter.set_process(stage_active)


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
