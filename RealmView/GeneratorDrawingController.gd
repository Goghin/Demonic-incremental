class_name GeneratorDrawingController
extends RefCounted


var geometry_controller: RealmLayoutGeometryController = RealmLayoutGeometryController.new()


func draw_generators(
	owner: Control,
	state: GameState,
	realm_layout: RealmLayout,
	island_rect: Rect2,
	generator_visual_renderer: GeneratorVisualRenderer,
	generator_layer: Node2D,
	generator_sprites: Dictionary,
	generator_hitboxes: Dictionary,
	lava_mite_visual_controller: LavaMiteVisualController,
	matter_furnace_visual_controller: MatterFurnaceVisualController,
	molecular_agitation_particle_controller: MolecularAgitationParticleController
) -> void:
	var active_generators: Array = _collect_active_generators(state)

	generator_hitboxes.clear()

	var active_ids: Dictionary = {}
	var machine_size: float = 20.0

	for generator in active_generators:
		_draw_generator(
			owner,
			generator,
			realm_layout,
			island_rect,
			generator_visual_renderer,
			generator_layer,
			generator_sprites,
			generator_hitboxes,
			active_ids,
			machine_size,
			lava_mite_visual_controller,
			matter_furnace_visual_controller,
			molecular_agitation_particle_controller
		)

	generator_visual_renderer.update_generator_visibility(
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
	owner: Control,
	generator: Generator,
	realm_layout: RealmLayout,
	island_rect: Rect2,
	generator_visual_renderer: GeneratorVisualRenderer,
	generator_layer: Node2D,
	generator_sprites: Dictionary,
	generator_hitboxes: Dictionary,
	active_ids: Dictionary,
	machine_size: float,
	lava_mite_visual_controller: LavaMiteVisualController,
	matter_furnace_visual_controller: MatterFurnaceVisualController,
	molecular_agitation_particle_controller: MolecularAgitationParticleController
) -> void:
	var generator_id: String = generator.definition.id
	active_ids[generator_id] = true

	if not realm_layout.generator_layout_positions.has(generator_id):
		return

	var normalized_position: Vector2 = realm_layout.generator_layout_positions[generator_id]
	var generator_position: Vector2 = geometry_controller.get_position_from_normalized(
		normalized_position,
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
		size_multiplier,
		generator_visual_renderer,
		generator_layer,
		generator_sprites,
		generator_hitboxes,
		lava_mite_visual_controller,
		matter_furnace_visual_controller
	):
		return

	if generator_id == "thermal_furnace":
		molecular_agitation_particle_controller.ensure_overlay(
			owner,
			generator,
			generator_position
		)

	_draw_standard_generator(
		generator,
		generator_id,
		generator_position,
		machine_size,
		size_multiplier,
		generator_visual_renderer,
		generator_layer,
		generator_sprites,
		generator_hitboxes
	)


func _draw_special_generator(
	owner: Control,
	generator: Generator,
	generator_id: String,
	generator_position: Vector2,
	machine_size: float,
	size_multiplier: float,
	generator_visual_renderer: GeneratorVisualRenderer,
	generator_layer: Node2D,
	generator_sprites: Dictionary,
	generator_hitboxes: Dictionary,
	lava_mite_visual_controller: LavaMiteVisualController,
	matter_furnace_visual_controller: MatterFurnaceVisualController
) -> bool:
	if generator_id == "lava_mite_colony":
		lava_mite_visual_controller.update(
			generator_visual_renderer,
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
		matter_furnace_visual_controller.update(
			generator_visual_renderer,
			generator_layer,
			generator_sprites,
			generator,
			generator_position,
			machine_size,
			generator_hitboxes
		)
		return true

	return false


func _draw_standard_generator(
	generator: Generator,
	generator_id: String,
	generator_position: Vector2,
	machine_size: float,
	size_multiplier: float,
	generator_visual_renderer: GeneratorVisualRenderer,
	generator_layer: Node2D,
	generator_sprites: Dictionary,
	generator_hitboxes: Dictionary
) -> void:
	var texture: Texture2D = generator_visual_renderer.get_texture(generator)

	if texture != null:
		var texture_scale: float = generator_visual_renderer.get_texture_scale(
			texture,
			machine_size,
			size_multiplier
		)

		generator_hitboxes[generator_id] = generator_visual_renderer.get_texture_hitbox(
			texture,
			generator_position,
			texture_scale
		)

		var sprite: Sprite2D = generator_visual_renderer.get_or_create_sprite(
			generator_layer,
			generator_sprites,
			generator_id
		)

		generator_visual_renderer.update_sprite(
			sprite,
			generator,
			texture,
			generator_position,
			texture_scale
		)
	else:
		generator_hitboxes[generator_id] = generator_visual_renderer.get_fallback_hitbox(
			generator_position,
			machine_size,
			size_multiplier
		)
