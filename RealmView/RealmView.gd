class_name RealmView
extends Control

var state: GameState
var generator_visual_renderer: GeneratorVisualRenderer = GeneratorVisualRenderer.new()
var generator_drawing_controller: GeneratorDrawingController = GeneratorDrawingController.new()
var generator_animation_controller: GeneratorAnimationController = GeneratorAnimationController.new()
var lava_mite_visual_controller: LavaMiteVisualController = LavaMiteVisualController.new()
var matter_furnace_visual_controller: MatterFurnaceVisualController = MatterFurnaceVisualController.new()
var lava_realm_visual_controller: LavaRealmVisualController = LavaRealmVisualController.new()
var ash_visual_controller: AshVisualController = AshVisualController.new()
var generator_sprites: Dictionary = {}
var generator_layer: Node2D

var molecular_agitation_particle_controller: MolecularAgitationParticleController = MolecularAgitationParticleController.new()

var braziers: Dictionary = {}

var crystallized_flame_visual_controller: CrystallizedFlameVisualController = CrystallizedFlameVisualController.new()

# Compatibility accessor for effects that still read crystals from RealmView.
var crystallized_flames: Array[CrystallizedFlame]:
	get:
		return crystallized_flame_visual_controller.crystals


const REALM_VISUAL_SCALE: float = 1.0
const REALM_VISUAL_OFFSET: Vector2 = Vector2(0.0, 0.0)
const ISLAND_BASE_SIZE: Vector2 = Vector2(418.0, 156.0)
const ISLAND_SCALE: float = 2.0
const ISLAND_CENTER_RATIO: Vector2 = Vector2(0.68, 0.66)
const ASH_VISUAL_RADIUS: float = 190.0

var realm_layout: Resource
var realm_rebuild_controller: RealmRebuildController = RealmRebuildController.new()

const LAVA_LAKE_SCENE = preload(
	"res://RealmView/LavaLake.tscn"
)

const LAVA_FLOW_SCENE = preload(
	"res://RealmView/lavaflow.tscn"
)

const LAVA_FALL_SCENE = preload(
	"res://RealmView/lavafall.tscn"
)


var generator_hitboxes: Dictionary = {}

var forge_activity_visual_controller: ForgeActivityVisualController = ForgeActivityVisualController.new()
var brazier_visual_controller: BrazierVisualController = BrazierVisualController.new()
var island_visual_controller: IslandVisualController = IslandVisualController.new()
var realm_layout_overlay_renderer: RealmLayoutOverlayRenderer = RealmLayoutOverlayRenderer.new()
var realm_layout_debug_controller: RealmLayoutDebugController = RealmLayoutDebugController.new()
var realm_layout_editor_controller: RealmLayoutEditorController = RealmLayoutEditorController.new()
var realm_background_renderer: RealmBackgroundRenderer = RealmBackgroundRenderer.new()

const BRAZIER_SCENE = preload(
	"res://RealmView/Brazier.tscn"
)

const BRAZIER_STATS: Array[String] = [
	"stability",
	"density",
	"integrity",
	"intensity",
	"resonance"
]

func setup(game_state: GameState) -> void:
	state = game_state
	generator_layer = generator_visual_renderer.setup_layer(
		self,
		generator_layer
	)

	scale = Vector2(
		REALM_VISUAL_SCALE,
		REALM_VISUAL_SCALE
	)

	pivot_offset = size * 0.5
	position = REALM_VISUAL_OFFSET

	brazier_visual_controller.setup(
		self,
		braziers,
		BRAZIER_STATS,
		BRAZIER_SCENE
	)
	realm_layout_overlay_renderer.setup(self)

	rebuild_realm(state.realm_layout)

func rebuild_realm(new_layout: RealmLayout) -> void:
	realm_rebuild_controller.rebuild(self, new_layout)

func update_flame_visuals() -> void:
	crystallized_flame_visual_controller.update(
		self,
		state
	)


func _process(_delta: float) -> void:
	if state == null:
		return

	crystallized_flame_visual_controller.update_if_needed(
		self,
		state
	)

	forge_activity_visual_controller.advance(_delta)
	generator_animation_controller.update_phase(
		&"early",
		self,
		state,
		generator_sprites,
		_delta
	)
	lava_realm_visual_controller.update_lakes(
		state,
		realm_layout
	)
	lava_realm_visual_controller.update_flow_states(
		state,
		realm_layout
	)
	generator_animation_controller.update_phase(
		&"middle",
		self,
		state,
		generator_sprites,
		_delta
	)
	molecular_agitation_particle_controller.update(
		state.generators.get("thermal_furnace"),
		_get_generator_position("thermal_furnace")
	)
	generator_animation_controller.update_phase(
		&"late",
		self,
		state,
		generator_sprites,
		_delta
	)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if state == null or realm_layout == null:
		return

	realm_layout_editor_controller.handle_input(
		event,
		self,
		realm_layout,
		ash_visual_controller.piles,
		braziers,
		BRAZIER_STATS,
		generator_hitboxes,
		_get_island_rect(),
		state.get_resource_amount(ResourceIds.ASH),
		Callable(self, "_update_ash_piles"),
		Callable(self, "queue_redraw"),
		realm_layout_debug_controller,
		lava_realm_visual_controller.lakes
	)

func _draw() -> void:
	if state == null:
		return

	var center: Vector2 = size * ISLAND_CENTER_RATIO

	brazier_visual_controller.update_stat_values(
		braziers,
		BRAZIER_STATS,
		state.realm_configuration
	)

	var ash: float = state.get_resource_amount(
		ResourceIds.ASH
	)
	ash_visual_controller.update_piles(
		realm_layout,
		_get_island_rect(),
		ash
	)

	# ------------------------------------------------------------
	# Neutral realm dimensions
	# ------------------------------------------------------------

	realm_background_renderer.draw_background(self, center)

	var island_rect: Rect2 = _get_island_rect()

	# ------------------------------------------------------------
	# Floating island
	# ------------------------------------------------------------

	brazier_visual_controller.position_braziers(
		braziers,
		BRAZIER_STATS,
		realm_layout,
		island_rect
	)

	# ------------------------------------------------------------
	# Generators
	# ------------------------------------------------------------

	_draw_generators()

	forge_activity_visual_controller.update(
		self,
		state.generators.get("infernal_forge"),
		_get_generator_position("infernal_forge")
	)

	# ------------------------------------------------------------
	# Ash
	# ------------------------------------------------------------

	ash_visual_controller.update_contamination(
		self,
		center,
		ASH_VISUAL_RADIUS,
		ash
	)

	# ------------------------------------------------------------
	# Layout mode
	# ------------------------------------------------------------

	realm_layout_overlay_renderer.update_overlay(
		realm_layout_editor_controller.layout_mode,
		generator_hitboxes,
		ash_visual_controller.piles,
		braziers,
		BRAZIER_STATS
	)

func _get_island_rect() -> Rect2:
	var center: Vector2 = size * ISLAND_CENTER_RATIO
	var island_size: Vector2 = ISLAND_BASE_SIZE * ISLAND_SCALE

	return Rect2(
		center - island_size * 0.5,
		island_size
	)

func _draw_generators() -> void:
	generator_drawing_controller.draw_generators(
		self,
		state,
		realm_layout,
		_get_island_rect(),
		generator_visual_renderer,
		generator_layer,
		generator_sprites,
		generator_hitboxes,
		lava_mite_visual_controller,
		matter_furnace_visual_controller,
		molecular_agitation_particle_controller
	)

func _get_generator_position(
	generator_id: String
) -> Vector2:
	return generator_visual_renderer.get_generator_position(
		generator_id,
		realm_layout.generator_layout_positions,
		size,
		_get_island_rect()
	)

func _update_ash_piles(ash: float) -> void:
	ash_visual_controller.update_piles(
		realm_layout,
		_get_island_rect(),
		ash
	)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		lava_realm_visual_controller.update_positions(
			realm_layout,
			_get_island_rect()
		)
		island_visual_controller.update(
			self,
			realm_layout,
			_get_island_rect()
		)

func begin_prestige_destruction() -> void:
	crystallized_flame_visual_controller.begin_prestige_destruction()


func play_crystallization_event(
	crystals_created: float
) -> void:
	crystallized_flame_visual_controller.play_crystallization_event(
		self,
		state,
		crystals_created,
		_get_generator_position("infernal_forge")
	)


# ------------------------------------------------------------
# LAVA NETWORK
# ------------------------------------------------------------


