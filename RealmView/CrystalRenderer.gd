class_name CrystalRenderer
extends RefCounted


const CRYSTALLIZED_FLAME_SCENE = preload(
	"res://RealmView/CrystallizedFlame.tscn"
)

const CRYSTAL_BASE_SCALE: float = 0.08
const CRYSTAL_CENTER: Vector2 = Vector2(0.68, 0.33)
const MAX_VISIBLE_CRYSTALS: int = 25
const CRYSTAL_Z_INDEX: int = 25
const CRYSTAL_VALUE_SCALE_FACTOR: float = 0.12
const MAX_CRYSTAL_VALUE_SCALE: float = 2.5
const CRYSTAL_POSITIONS: Array[Vector2] = [
	Vector2(0, -35),
	Vector2(-30, -20),
	Vector2(30, -20),
	Vector2(-60, -5),
	Vector2(60, -5),
	Vector2(-90, 12),
	Vector2(90, 12),
	Vector2(-35, 15),
	Vector2(35, 15),
	Vector2(-120, 32),
	Vector2(120, 32),
	Vector2(-75, 38),
	Vector2(75, 38),
	Vector2(-25, 45),
	Vector2(25, 45),
	Vector2(-145, 58),
	Vector2(145, 58),
	Vector2(-100, 65),
	Vector2(100, 65),
	Vector2(-50, 72),
	Vector2(50, 72),
	Vector2(0, 70),
	Vector2(-170, 85),
	Vector2(170, 85),
	Vector2(-70, 90)
]


func update(
	owner: Control,
	crystals: Array[CrystallizedFlame],
	crystal_values: Array[float],
	total_flames: float
) -> void:
	var target_count: int = _get_target_count(total_flames)
	_update_crystal_count(owner, crystals, target_count)
	_update_crystal_values(crystals, crystal_values, total_flames)
	_position_crystals(owner, crystals, crystal_values)


func _update_crystal_count(
	owner: Control,
	crystals: Array[CrystallizedFlame],
	target_count: int
) -> void:
	while crystals.size() < target_count:
		_create_crystal(owner, crystals)

	while crystals.size() > target_count:
		_remove_crystal(crystals)


func _get_target_count(total_flames: float) -> int:
	return min(
		int(floor(total_flames)),
		MAX_VISIBLE_CRYSTALS
	)


func _create_crystal(
	owner: Control,
	crystals: Array[CrystallizedFlame]
) -> void:
	var crystal: CrystallizedFlame = (
		CRYSTALLIZED_FLAME_SCENE.instantiate()
	)

	crystal.scale = Vector2(
		CRYSTAL_BASE_SCALE,
		CRYSTAL_BASE_SCALE
	)
	crystal.position = owner.size * CRYSTAL_CENTER
	crystal.z_index = CRYSTAL_Z_INDEX

	owner.add_child(crystal)
	crystals.append(crystal)


func _remove_crystal(
	crystals: Array[CrystallizedFlame]
) -> void:
	if crystals.is_empty():
		return

	var crystal: CrystallizedFlame = crystals.pop_back()
	crystal.queue_free()


func _update_crystal_values(
	crystals: Array[CrystallizedFlame],
	crystal_values: Array[float],
	total_flames: float
) -> void:
	crystal_values.clear()

	var count: int = crystals.size()
	if count == 0:
		return

	var remaining: float = max(
		total_flames - float(count),
		0.0
	)

	var total_weight: float = 0.0
	for i in range(count):
		total_weight += float(i + 1)

	for i in range(count):
		var value: float = 1.0
		if remaining > 0.0:
			var weight: float = float(i + 1)
			value += remaining * weight / total_weight

		crystal_values.append(value)


func _position_crystals(
	owner: Control,
	crystals: Array[CrystallizedFlame],
	crystal_values: Array[float]
) -> void:
	if crystals.is_empty():
		return

	var center: Vector2 = owner.size * CRYSTAL_CENTER

	var position_count: int = min(
		crystals.size(),
		CRYSTAL_POSITIONS.size()
	)

	for i in range(position_count):
		var crystal: CrystallizedFlame = crystals[i]
		var crystal_position: Vector2 = center + CRYSTAL_POSITIONS[i]

		var flame_value: float = 1.0
		if i < crystal_values.size():
			flame_value = crystal_values[i]

		var value_scale: float = (
			1.0 + log(flame_value) * CRYSTAL_VALUE_SCALE_FACTOR
		)
		value_scale = clamp(
			value_scale,
			1.0,
			MAX_CRYSTAL_VALUE_SCALE
		)

		crystal.scale = Vector2(
			CRYSTAL_BASE_SCALE,
			CRYSTAL_BASE_SCALE
		) * value_scale

		var rotation_amount: float = 0.0
		if crystal_position.x < center.x:
			rotation_amount = -0.20
		elif crystal_position.x > center.x:
			rotation_amount = 0.20

		crystal.set_base_transform(
			crystal_position,
			rotation_amount
		)
