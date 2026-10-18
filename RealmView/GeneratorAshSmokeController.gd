class_name GeneratorAshSmokeController
extends RefCounted


const ASH_PRODUCING_GENERATORS: Array[String] = [
	"molecular_agitation",
	"thermal_furnace",
	"matter_furnace",
	"infernal_forge"
]
const DEFAULT_EMITTER_COUNT: int = 3
const EMITTER_COUNT_BY_GENERATOR: Dictionary = {
	"matter_furnace": 5
}
# Indices are activated in order, from the first plume to the last.
const DEFAULT_EMITTER_STAGE_ORDER: Array[int] = [1, 0, 2]
const EMITTER_STAGE_ORDER_BY_GENERATOR: Dictionary = {
	# Center first, then inner pair, then outer pair.
	"matter_furnace": [1, 3, 4, 0, 2]
}
const MAX_NORMALIZED_ASH_OUTPUT: float = 1.0
# A slightly lower power makes smoke build a little sooner at low Ash output.
const ASH_OUTPUT_CURVE_POWER: float = 2.0
const EMITTER_SIZE_MIN: Array[float] = [0.32, 0.28, 0.24, 0.22, 0.22]
const EMITTER_SIZE_MAX: Array[float] = [1.00, 1.35, 0.90, 0.82, 0.82]
const EMITTER_RATE_MIN: Array[float] = [0.12, 0.10, 0.08, 0.07, 0.07]
const EMITTER_RATE_MAX: Array[float] = [1.35, 1.65, 1.05, 0.95, 0.95]
const EMITTER_OPACITY_MIN: Array[float] = [0.10, 0.08, 0.07, 0.06, 0.06]
const EMITTER_OPACITY_MAX: Array[float] = [0.52, 0.62, 0.45, 0.40, 0.40]

# Ash output rate at which each generator reaches maximum smoke intensity.
# Tune these independently to match each generator's expected production range.
const ASH_OUTPUT_TARGET_BY_GENERATOR: Dictionary = {
	"molecular_agitation": 1000.0,
	"thermal_furnace": 1000.0,
	"matter_furnace": 1000.0,
	"infernal_forge": 1000.0
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
		Vector2(-0.42, -0.20),
		Vector2(0.0, -0.36),
		Vector2(0.42, -0.20),
		Vector2(-0.22, -0.30),
		Vector2(0.22, -0.30)
	],
	"infernal_forge": [
		Vector2(-0.20, -0.10),
		Vector2(0.0, -0.22),
		Vector2(0.20, -0.10)
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
			float(ASH_OUTPUT_TARGET_BY_GENERATOR.get(generator_id, 1000.0)),
			0.001
		)
		var normalized_output: float = 0.0
		if active and ash_rate > 0.0:
			var logarithmic_output: float = log(1.0 + ash_rate) / log(1.0 + target_rate)
			normalized_output = clampf(
				pow(logarithmic_output, ASH_OUTPUT_CURVE_POWER),
				0.0,
				MAX_NORMALIZED_ASH_OUTPUT
			)

		var emitter_count: int = _get_emitter_count(generator_id)
		var stage_order: Array = _get_emitter_stage_order(generator_id)
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
			var stage: int = stage_order.find(index)
			var stage_start: float = float(stage) / float(emitter_count)
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
	while emitters.size() < _get_emitter_count(generator_id):
		var emitter := SmokeEmitterRenderer.new()
		emitter.name = "%s_AshSmoke_%d" % [generator_id, emitters.size() + 1]
		emitter.z_index = 15
		owner.add_child(emitter)
		emitters.append(emitter)
	emitters_by_generator[generator_id] = emitters
	return emitters


func _get_emitter_count(generator_id: String) -> int:
	return int(EMITTER_COUNT_BY_GENERATOR.get(generator_id, DEFAULT_EMITTER_COUNT))


func _get_emitter_stage_order(generator_id: String) -> Array:
	return EMITTER_STAGE_ORDER_BY_GENERATOR.get(
		generator_id,
		DEFAULT_EMITTER_STAGE_ORDER
	)


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
