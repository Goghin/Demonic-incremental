class_name RealmView
extends Control

var state: GameState
var generator_visual_renderer: GeneratorVisualRenderer = GeneratorVisualRenderer.new()
var generator_visibility_controller: GeneratorVisibilityController = GeneratorVisibilityController.new()
var generator_visual_reset_controller: GeneratorVisualResetController = GeneratorVisualResetController.new()
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
var realm_draw_controller: RealmDrawController = RealmDrawController.new()
var realm_update_controller: RealmUpdateController = RealmUpdateController.new()
var realm_scene_visual_controller: RealmSceneVisualController = RealmSceneVisualController.new()
var realm_setup_controller: RealmSetupController = RealmSetupController.new()
var realm_layout_geometry_controller: RealmLayoutGeometryController = RealmLayoutGeometryController.new()
var realm_resize_controller: RealmResizeController = RealmResizeController.new()
var realm_layout_visual_controller: RealmLayoutVisualController = RealmLayoutVisualController.new()
var realm_rebuild_state_controller: RealmRebuildStateController = RealmRebuildStateController.new()

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
	realm_setup_controller.setup(self, game_state)

func rebuild_realm(new_layout: RealmLayout) -> void:
	realm_rebuild_controller.rebuild(self, new_layout)

func update_flame_visuals() -> void:
	crystallized_flame_visual_controller.update(
		self,
		state
	)


func _process(_delta: float) -> void:
	realm_update_controller.update(self, _delta)

func _update_scene_visuals(island_rect: Rect2) -> void:
	realm_scene_visual_controller.update(self, island_rect)


func _input(event: InputEvent) -> void:
	realm_layout_editor_controller.handle_owner_input(event, self)

func _draw() -> void:
	realm_draw_controller.draw(self)

func _get_island_rect() -> Rect2:
	return realm_layout_geometry_controller.get_island_rect(
		size,
		ISLAND_CENTER_RATIO,
		ISLAND_BASE_SIZE,
		ISLAND_SCALE
	)

func _draw_generators(island_rect: Rect2) -> void:
	generator_drawing_controller.draw_generators(self, island_rect)

func _get_generator_position(
	generator_id: String
) -> Vector2:
	return _get_generator_position_in_rect(
		generator_id,
		_get_island_rect()
	)

func _get_generator_position_in_rect(
	generator_id: String,
	island_rect: Rect2
) -> Vector2:
	if realm_layout == null:
		return size * 0.5

	return realm_layout_geometry_controller.get_generator_position(
		generator_id,
		realm_layout.generator_layout_positions,
		size,
		island_rect
	)

func _update_ash_piles(ash: float) -> void:
	ash_visual_controller.update_piles(
		realm_layout,
		_get_island_rect(),
		ash
	)

func _notification(what: int) -> void:
	realm_resize_controller.handle_notification(self, what)

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
