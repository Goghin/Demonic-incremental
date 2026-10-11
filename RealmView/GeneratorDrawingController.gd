class_name GeneratorDrawingController
extends RefCounted


var geometry_controller: RealmLayoutGeometryController = (
	RealmLayoutGeometryController.new()
)
var standard_generator_drawer: StandardGeneratorDrawer = (
	StandardGeneratorDrawer.new()
)


func draw_generators(
	parent: Node,
	state: GameState,
	realm_layout: Resource,
	view_size: Vector2,
	island_rect: Rect2,
	generator_hitboxes: Dictionary,
	generator_visibility_controller: GeneratorVisibilityController,
	generator_sprites: Dictionary,
	generator_visual_renderer: GeneratorVisualRenderer,
	generator_layer: Node2D,
	lava_mite_visual_controller: LavaMiteVisualController,
	matter_furnace_visual_controller: MatterFurnaceVisualController,
	molecular_agitation_particle_controller: MolecularAgitationParticleController
) -> void:
	if state == null or realm_layout == null:
		return

	var active_generators: Array = _collect_active_generators(state)
	generator_hitboxes.clear()

	var active_ids: Dictionary = {}
	var machine_size: float = 20.0

	for generator in active_generators:
		_draw_generator(
			parent,
			realm_layout,
			view_size,
			island_rect,
			generator_hitboxes,
			generator_visual_renderer,
			generator_layer,
			generator_sprites,
			lava_mite_visual_controller,
			matter_furnace_visual_controller,
			molecular_agitation_particle_controller,
			generator,
			active_ids,
			machine_size
		)

	generator_visibility_controller.update_visibility(
		active_ids,
		generator_sprites
	)


func _collect_active_generators(state: GameState) -> Array:
	var active_generators: Array = []

	for generator_value in state.generators.values():
		var generator: Generator = generator_value
		var generator_id: String = generator.definition.id

		if generator.unlocked and (
			generator.level > 0 or
			generator_id == "infernal_forge"
		):
			active_generators.append(generator)

	return active_generators


func _draw_generator(
	parent: Node,
	realm_layout: Resource,
	view_size: Vector2,
	island_rect: Rect2,
	generator_hitboxes: Dictionary,
	visual_renderer: GeneratorVisualRenderer,
	generator_layer: Node2D,
	generator_sprites: Dictionary,
	lava_mite_controller: LavaMiteVisualController,
	matter_furnace_controller: MatterFurnaceVisualController,
	molecular_agitation_particle_controller: MolecularAgitationParticleController,
	generator: Generator,
	active_ids: Dictionary,
	machine_size: float
) -> void:
	var generator_id: String = generator.definition.id

	if not realm_layout.generator_layout_positions.has(generator_id):
		return

	# Only generators with a valid layout position count as drawable. This
	# ensures stale sprites are hidden by update_visibility().
	active_ids[generator_id] = true

	var generator_position: Vector2 = geometry_controller.get_generator_position(
		generator_id,
		realm_layout.generator_layout_positions,
		view_size,
		island_rect
	)

	var size_multiplier: float = 1.0
	if generator_id == "infernal_forge":
		size_multiplier = 1.8

	if _draw_special_generator(
		lava_mite_controller,
		matter_furnace_controller,
		visual_renderer,
		generator_layer,
		generator_sprites,
		generator_hitboxes,
		generator,
		generator_id,
		generator_position,
		machine_size,
		size_multiplier
	):
		return

	if generator_id == "thermal_furnace":
		molecular_agitation_particle_controller.ensure_overlay(
			parent,
			generator,
			generator_position
		)

	standard_generator_drawer.draw(
		visual_renderer,
		generator_layer,
		generator_sprites,
		generator_hitboxes,
		generator,
		generator_id,
		generator_position,
		machine_size,
		size_multiplier
	)


func _draw_special_generator(
	lava_mite_controller: LavaMiteVisualController,
	matter_furnace_controller: MatterFurnaceVisualController,
	visual_renderer: GeneratorVisualRenderer,
	generator_layer: Node2D,
	generator_sprites: Dictionary,
	generator_hitboxes: Dictionary,
	generator: Generator,
	generator_id: String,
	generator_position: Vector2,
	machine_size: float,
	size_multiplier: float
) -> bool:
	if generator_id == "lava_mite_colony":
		lava_mite_controller.update(
			visual_renderer,
			generator_layer,
			generator_sprites,
			generator,
			generator_position,
			machine_size,
			size_multiplier,
			generator_hitboxes
		)
		return true

	if generator_id == "matter_furnace":
		matter_furnace_controller.update(
			visual_renderer,
			generator_layer,
			generator_sprites,
			generator,
			generator_position,
			machine_size,
			generator_hitboxes
		)
		return true

	return false
