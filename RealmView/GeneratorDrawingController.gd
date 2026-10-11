
class_name GeneratorDrawingController
extends RefCounted


var geometry_controller: RealmLayoutGeometryController = (
	RealmLayoutGeometryController.new()
)


func draw_generators(owner: Control) -> void:
	if owner.state == null or owner.realm_layout == null:
		return

	var active_generators: Array = _collect_active_generators(
		owner.state
	)

	owner.generator_hitboxes.clear()

	var active_ids: Dictionary = {}
	var machine_size: float = 20.0
	var island_rect: Rect2 = owner._get_island_rect()

	for generator in active_generators:
		_draw_generator(
			owner,
			generator,
			island_rect,
			active_ids,
			machine_size
		)

	owner.generator_visual_renderer.update_generator_visibility(
		active_ids,
		owner.generator_sprites
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
	island_rect: Rect2,
	active_ids: Dictionary,
	machine_size: float
) -> void:
	var generator_id: String = generator.definition.id
	active_ids[generator_id] = true

	if not owner.realm_layout.generator_layout_positions.has(
		generator_id
	):
		return

	var normalized_position: Vector2 = (
		owner.realm_layout.generator_layout_positions[
			generator_id
		]
	)

	var generator_position: Vector2 = (
		geometry_controller.get_position_from_normalized(
			normalized_position,
			island_rect
		)
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

	_draw_standard_generator(
		owner,
		generator,
		generator_id,
		generator_position,
		machine_size,
		size_multiplier
	)


func _draw_special_generator(
	owner: Control,
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


func _draw_standard_generator(
	owner: Control,
	generator: Generator,
	generator_id: String,
	generator_position: Vector2,
	machine_size: float,
	size_multiplier: float
) -> void:
	var texture: Texture2D = (
		owner.generator_visual_renderer.get_texture(generator)
	)

	if texture != null:
		var texture_scale: float = (
			owner.generator_visual_renderer.get_texture_scale(
				texture,
				machine_size,
				size_multiplier
			)
		)

		owner.generator_hitboxes[generator_id] = (
			owner.generator_visual_renderer.get_texture_hitbox(
				texture,
				generator_position,
				texture_scale
			)
		)

		var sprite: Sprite2D = (
			owner.generator_visual_renderer.get_or_create_sprite(
				owner.generator_layer,
				owner.generator_sprites,
				generator_id
			)
		)

		owner.generator_visual_renderer.update_sprite(
			sprite,
			generator,
			texture,
			generator_position,
			texture_scale
		)
	else:
		owner.generator_hitboxes[generator_id] = (
			owner.generator_visual_renderer.get_fallback_hitbox(
				generator_position,
				machine_size,
				size_multiplier
			)
		)
