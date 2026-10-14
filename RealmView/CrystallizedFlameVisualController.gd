class_name CrystallizedFlameVisualController
extends RefCounted


var crystals: Array[CrystallizedFlame] = []
var crystal_values: Array[float] = []
var renderer: CrystalRenderer = CrystalRenderer.new()
var stream_controller: CrystallizationStreamController = CrystallizationStreamController.new()
var last_flame_amount: float = -1.0


func reset_and_update(
	owner: Control,
	state: GameState
) -> void:
	last_flame_amount = -1.0
	update(owner, state)


func update_if_needed(
	owner: Control,
	state: GameState
) -> void:
	if state == null:
		return

	var current_flames: float = state.get_resource_amount(
		ResourceIds.CRYSTALLIZED_FLAME
	)

	if is_equal_approx(current_flames, last_flame_amount):
		return

	last_flame_amount = current_flames
	update(owner, state)


func reposition(owner: Control) -> void:
	# Reposition existing crystals without changing their count or values.
	# Crystals already in the prestige destruction animation are left alone.
	renderer.reposition(owner, crystals, crystal_values)


func update(
	owner: Control,
	state: GameState
) -> void:
	if state == null:
		return

	var total_flames: float = state.get_resource_amount(
		ResourceIds.CRYSTALLIZED_FLAME
	)

	renderer.update(
		owner,
		crystals,
		crystal_values,
		total_flames
	)


func begin_prestige_destruction() -> void:
	if crystals.is_empty():
		return

	print(
		"BEGIN PRESTIGE DESTRUCTION: ",
		crystals.size(),
		" crystals"
	)

	var first_index: int = randi_range(
		0,
		crystals.size() - 1
	)

	var first_crystal: CrystallizedFlame = crystals[first_index]

	print(
		"Starting chain reaction with crystal ",
		first_index,
		" at ",
		first_crystal.position
	)

	first_crystal.begin_destruction(0.0)


func play_crystallization_event(
	owner: Control,
	state: GameState,
	crystals_created: float,
	forge_position: Vector2
) -> void:
	if state == null:
		return

	stream_controller.play_crystallization_event(
		owner,
		crystals_created,
		forge_position,
		crystals,
		crystal_values,
		state.get_resource_amount(ResourceIds.CRYSTALLIZED_FLAME),
		renderer
	)
