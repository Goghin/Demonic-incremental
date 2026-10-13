class_name GeneratorDrawingController
extends RefCounted


var standard_generator_drawer: StandardGeneratorDrawer = (
	StandardGeneratorDrawer.new()
)


func draw_generators(owner: RealmView, island_rect: Rect2) -> void:
	owner.generator_hitboxes.clear()

	if owner.state == null or owner.realm_layout == null:
		# A missing state/layout must not leave old machines clickable or visible.
		owner.generator_visibility_controller.update_visibility(
			{},
			owner.generator_sprites
		)
		return

	var active_generators: Array = _collect_active_generators(owner.state)

	var active_ids: Dictionary = {}
	var machine_size: float = 20.0

	for generator in active_generators:
		_draw_generator(
			owner,
			island_rect,
			generator,
			active_ids,
			machine_size
		)

	owner.generator_visibility_controller.update_visibility(
		active_ids,
		owner.generator_sprites
	)


func _collect_active_generators(state: GameState) -> Array:
	var active_generators: Array = []

	for generator_value in state.generators.values():
		var generator: Generator = generator_value
		var generator_id: String = generator.definition.id

		# Unlocked level-zero generators are shown as dormant, clickable machines.
		if generator.unlocked:
			active_generators.append(generator)

	return active_generators


func _draw_generator(
	owner: RealmView,
	island_rect: Rect2,
	generator: Generator,
	active_ids: Dictionary,
	machine_size: float
) -> void:
	var generator_id: String = generator.definition.id

	if not owner.realm_layout.generator_layout_positions.has(generator_id):
		return

	# Only generators with a valid layout position count as drawable. This
	# ensures stale sprites are hidden by update_visibility().
	active_ids[generator_id] = true

	var generator_position: Vector2 = owner.realm_layout_geometry_controller.get_generator_position(
		generator_id,
		owner.realm_layout.generator_layout_positions,
		owner.size,
		island_rect
	)

	var size_multiplier: float = 1.0
	if generator_id == "infernal_forge":
		size_multiplier = 1.8

	if _draw_special_generator(
		owner,
		generator,
		generator_id,
		generator_position,
		machine_size,
		size_multiplier
	):
		return

	if generator_id == "thermal_furnace":
		owner.molecular_agitation_particle_controller.ensure_overlay(
			owner,
			generator,
			generator_position
		)

	standard_generator_drawer.draw(
		owner.generator_visual_renderer,
		owner.generator_layer,
		owner.generator_sprites,
		owner.generator_hitboxes,
		generator,
		generator_id,
		generator_position,
		machine_size,
		size_multiplier
	)


func _draw_special_generator(
	owner: RealmView,
	generator: Generator,
	generator_id: String,
	generator_position: Vector2,
	machine_size: float,
	size_multiplier: float
) -> bool:
	if generator_id == "lava_mite_colony":
		owner.lava_mite_visual_controller.update(
			owner.generator_visual_renderer,
			owner.generator_layer,
			owner.generator_sprites,
			generator,
			generator_position,
			machine_size,
			size_multiplier,
			owner.generator_hitboxes
		)
		return true

	if generator_id == "matter_furnace":
		owner.matter_furnace_visual_controller.update(
			owner.generator_visual_renderer,
			owner.generator_layer,
			owner.generator_sprites,
			generator,
			generator_position,
			machine_size,
			owner.generator_hitboxes
		)
		return true

	return false
