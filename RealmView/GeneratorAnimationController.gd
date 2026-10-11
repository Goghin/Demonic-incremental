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
				delta
			)
			_update_molecular_agitation(
				owner,
				state,
				generator_sprites,
				delta
			)
		&"middle":
			_update_furnace_swirl(
				owner,
				state,
				generator_sprites
			)
			_update_atomic_friction_particles(
				owner,
				state,
				generator_sprites
			)
		&"late":
			_update_atomic_friction_animation(
				state,
				generator_sprites,
				delta
			)


func _update_thermal_furnace(
	owner: Control,
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
	thermal_furnace.update(owner, furnace, sprite, delta)


func _update_molecular_agitation(
	owner: Control,
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
	molecular_agitation.update(owner, generator, sprite, delta)


func _update_furnace_swirl(
	owner: Control,
	state: GameState,
	generator_sprites: Dictionary
) -> void:
	if state == null or not generator_sprites.has("molecular_agitation"):
		return

	var furnace: Generator = state.generators.get("molecular_agitation")
	if furnace == null:
		return

	var sprite: Sprite2D = generator_sprites["molecular_agitation"]
	furnace_swirl.update(owner, furnace, sprite)


func _update_atomic_friction_particles(
	owner: Control,
	state: GameState,
	generator_sprites: Dictionary
) -> void:
	if state == null or not generator_sprites.has("atomic_friction"):
		return

	var generator: Generator = state.generators.get("atomic_friction")
	if generator == null:
		return

	var sprite: Sprite2D = generator_sprites["atomic_friction"]
	atomic_friction_particles.update(owner, generator, sprite)


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
