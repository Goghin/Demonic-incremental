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


func update_phase(
	phase: StringName,
	owner: Control,
	state: GameState,
	generator_sprites: Dictionary,
	delta: float
) -> void:
	match phase:
		&"early":
			_update_thermal_furnace(
				owner,
				state,
				generator_sprites,
				delta,
				thermal_furnace
			)
			_update_molecular_agitation(
				owner,
				state,
				generator_sprites,
				delta,
				molecular_agitation
			)
		&"middle":
			_update_furnace_swirl(
				owner,
				state,
				generator_sprites,
				furnace_swirl
			)
			_update_atomic_friction_particles(
				owner,
				state,
				generator_sprites,
				atomic_friction_particles
			)
		&"late":
			_update_atomic_friction_animation(
				state,
				generator_sprites,
				delta,
				atomic_friction_animation
			)


func _update_thermal_furnace(
	owner: Control,
	state: GameState,
	generator_sprites: Dictionary,
	delta: float,
	controller: ThermalFurnaceAnimationController
) -> void:
	if state == null or not generator_sprites.has("thermal_furnace"):
		return

	var furnace: Generator = state.generators.get("thermal_furnace")
	if furnace == null:
		return

	var sprite: Sprite2D = generator_sprites["thermal_furnace"]
	controller.update(owner, furnace, sprite, delta)


func _update_molecular_agitation(
	owner: Control,
	state: GameState,
	generator_sprites: Dictionary,
	delta: float,
	controller: MolecularAgitationSpriteController
) -> void:
	if state == null:
		return

	if not generator_sprites.has("molecular_agitation"):
		controller.hide()
		return

	var generator: Generator = state.generators.get("molecular_agitation")
	var sprite: Sprite2D = generator_sprites["molecular_agitation"]
	controller.update(owner, generator, sprite, delta)


func _update_furnace_swirl(
	owner: Control,
	state: GameState,
	generator_sprites: Dictionary,
	controller: FurnaceSwirlController
) -> void:
	if state == null or not generator_sprites.has("molecular_agitation"):
		return

	var furnace: Generator = state.generators.get("molecular_agitation")
	if furnace == null:
		return

	var sprite: Sprite2D = generator_sprites["molecular_agitation"]
	controller.update(owner, furnace, sprite)


func _update_atomic_friction_particles(
	owner: Control,
	state: GameState,
	generator_sprites: Dictionary,
	controller: AtomicFrictionParticleController
) -> void:
	if state == null or not generator_sprites.has("atomic_friction"):
		return

	var generator: Generator = state.generators.get("atomic_friction")
	if generator == null:
		return

	var sprite: Sprite2D = generator_sprites["atomic_friction"]
	controller.update(owner, generator, sprite)


func _update_atomic_friction_animation(
	state: GameState,
	generator_sprites: Dictionary,
	delta: float,
	controller: AtomicFrictionAnimationController
) -> void:
	if state == null or not generator_sprites.has("atomic_friction"):
		return

	var generator: Generator = state.generators.get("atomic_friction")
	if generator == null:
		return

	var sprite: Sprite2D = generator_sprites["atomic_friction"]
	controller.update(generator, sprite, delta)
