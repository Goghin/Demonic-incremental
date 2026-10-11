class_name GeneratorAnimationController
extends RefCounted


var thermal_furnace: ThermalFurnaceAnimationController = ThermalFurnaceAnimationController.new()
var molecular_agitation: MolecularAgitationSpriteController = MolecularAgitationSpriteController.new()
var furnace_swirl: FurnaceSwirlController = FurnaceSwirlController.new()
var atomic_friction_particles: AtomicFrictionParticleController = AtomicFrictionParticleController.new()
var atomic_friction_animation: AtomicFrictionAnimationController = AtomicFrictionAnimationController.new()


func reset() -> void:
	thermal_furnace.reset()
	molecular_agitation.hide()
	furnace_swirl.reset()
	atomic_friction_particles.reset()
	atomic_friction_animation.reset()


func update_early(
	generator_layer: Node2D,
	state: GameState,
	generator_sprites: Dictionary,
	delta: float
) -> void:
	_update_thermal_furnace(
		generator_layer,
		state,
		generator_sprites,
		delta
	)
	_update_molecular_agitation(
		generator_layer,
		state,
		generator_sprites,
		delta
	)


func update_middle(
	generator_layer: Node2D,
	state: GameState,
	generator_sprites: Dictionary
) -> void:
	_update_furnace_swirl(
		generator_layer,
		state,
		generator_sprites
	)
	_update_atomic_friction_particles(
		generator_layer,
		state,
		generator_sprites
	)


func update_late(
	state: GameState,
	generator_sprites: Dictionary,
	delta: float
) -> void:
	_update_atomic_friction_animation(
		state,
		generator_sprites,
		delta
	)


func _update_thermal_furnace(
	generator_layer: Node2D,
	state: GameState,
	generator_sprites: Dictionary,
	delta: float
) -> void:
	if state == null or not generator_sprites.has("thermal_furnace"):
		return

	var furnace: Generator = state.generators.get("thermal_furnace")
	if furnace == null:
		return

	var sprite: Sprite2D = generator_sprites["thermal_furnace"]
	thermal_furnace.update(generator_layer, furnace, sprite, delta)


func _update_molecular_agitation(
	generator_layer: Node2D,
	state: GameState,
	generator_sprites: Dictionary,
	delta: float
) -> void:
	if state == null:
		return

	if not generator_sprites.has("molecular_agitation"):
		molecular_agitation.hide()
		return

	var generator: Generator = state.generators.get("molecular_agitation")
	var sprite: Sprite2D = generator_sprites["molecular_agitation"]
	molecular_agitation.update(generator_layer, generator, sprite, delta)


func _update_furnace_swirl(
	generator_layer: Node2D,
	state: GameState,
	generator_sprites: Dictionary
) -> void:
	if state == null or not generator_sprites.has("molecular_agitation"):
		return

	var furnace: Generator = state.generators.get("molecular_agitation")
	if furnace == null:
		return

	var sprite: Sprite2D = generator_sprites["molecular_agitation"]
	furnace_swirl.update(generator_layer, furnace, sprite)


func _update_atomic_friction_particles(
	generator_layer: Node2D,
	state: GameState,
	generator_sprites: Dictionary
) -> void:
	if state == null or not generator_sprites.has("atomic_friction"):
		return

	var generator: Generator = state.generators.get("atomic_friction")
	if generator == null:
		return

	var sprite: Sprite2D = generator_sprites["atomic_friction"]
	atomic_friction_particles.update(generator_layer, generator, sprite)


func _update_atomic_friction_animation(
	state: GameState,
	generator_sprites: Dictionary,
	delta: float
) -> void:
	if state == null or not generator_sprites.has("atomic_friction"):
		return

	var generator: Generator = state.generators.get("atomic_friction")
	if generator == null:
		return

	var sprite: Sprite2D = generator_sprites["atomic_friction"]
	atomic_friction_animation.update(generator, sprite, delta)
