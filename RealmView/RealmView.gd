class_name RealmView
extends Control


signal generator_selected(generator_id: String)

var state: GameState
const VISUAL_EFFECT_OFF: int = 0
const VISUAL_EFFECT_LOW: int = 1
const VISUAL_EFFECT_MEDIUM: int = 2
const VISUAL_EFFECT_HIGH: int = 3

var visual_effect_quality: int = VISUAL_EFFECT_MEDIUM
var visual_effects_enabled: bool:
	get:
		return visual_effect_quality > VISUAL_EFFECT_OFF
var generator_visual_renderer: GeneratorVisualRenderer = GeneratorVisualRenderer.new()
var generator_visibility_controller: GeneratorVisibilityController = GeneratorVisibilityController.new()
var generator_visual_reset_controller: GeneratorVisualResetController = GeneratorVisualResetController.new()
var generator_drawing_controller: GeneratorDrawingController = GeneratorDrawingController.new()
var generator_animation_controller: GeneratorAnimationController = GeneratorAnimationController.new()
var lava_mite_visual_controller: LavaMiteVisualController = LavaMiteVisualController.new()
var matter_furnace_visual_controller: MatterFurnaceVisualController = MatterFurnaceVisualController.new()
var lava_realm_visual_controller: LavaRealmVisualController = LavaRealmVisualController.new()
var ash_visual_controller: AshVisualController = AshVisualController.new()
var matter_pile_visual_controller: MatterPileVisualController = MatterPileVisualController.new()
var generator_sprites: Dictionary = {}
var generator_layer: Node2D
var generator_selection_overlay: GeneratorSelectionOverlay

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
var smoke_visual_controller: SmokeVisualController = SmokeVisualController.new()
var generator_ash_smoke_controller: GeneratorAshSmokeController = GeneratorAshSmokeController.new()
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

const FORGE_LEVEL_REDUCTION_EFFECT = preload(
	"res://RealmView/ForgeLevelReductionEffect.gd"
)


var generator_hitboxes: Dictionary = {}
var selected_generator_id: String = ""

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

func set_visual_effects_enabled(enabled: bool) -> void:
	set_visual_effect_quality(
		VISUAL_EFFECT_MEDIUM if enabled else VISUAL_EFFECT_OFF
	)


func set_visual_effect_quality(quality: int) -> void:
	var normalized_quality: int = clampi(
		quality,
		VISUAL_EFFECT_OFF,
		VISUAL_EFFECT_HIGH
	)
	if visual_effect_quality == normalized_quality:
		return

	var was_enabled: bool = visual_effects_enabled
	visual_effect_quality = normalized_quality
	var is_enabled: bool = visual_effects_enabled

	if was_enabled and not is_enabled:
		generator_animation_controller.reset()
		molecular_agitation_particle_controller.reset()
		forge_activity_visual_controller.reset()


func setup(game_state: GameState) -> void:
	if generator_selection_overlay == null:
		generator_selection_overlay = GeneratorSelectionOverlay.new()
		generator_selection_overlay.name = "GeneratorSelectionOverlay"
		generator_selection_overlay.z_index = 11
		add_child(generator_selection_overlay)
		generator_selection_overlay.realm_view = self

	realm_setup_controller.setup(self, game_state)

func rebuild_realm(new_layout: RealmLayout) -> void:
	realm_rebuild_controller.rebuild(self, new_layout)

func update_flame_visuals() -> void:
	crystallized_flame_visual_controller.update(
		self,
		state
	)


func _process(_delta: float) -> void:
	realm_layout_editor_controller.update(self, _delta)
	realm_update_controller.update(self, _delta)
	# Refresh the selection ring and BUILD markers from the live generator state.
	if generator_selection_overlay != null:
		generator_selection_overlay.queue_redraw()

func _input(event: InputEvent) -> void:
	realm_layout_editor_controller.handle_owner_input(event, self)

	if realm_layout_editor_controller.layout_mode:
		return

	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	# The full-screen Game Control is the hovered control when the
	# RealmView itself ignores mouse input. Do not mistake that parent
	# container for an actual UI overlay, or machine clicks never reach us.
	var hovered_control: Control = get_viewport().gui_get_hovered_control()
	if hovered_control != null and hovered_control != get_parent():
		return

	var local_position: Vector2 = get_local_mouse_position()
	for generator_id in generator_hitboxes:
		var hitbox: Rect2 = generator_hitboxes[generator_id]
		if hitbox.has_point(local_position):
			generator_selected.emit(str(generator_id))
			get_viewport().set_input_as_handled()
			return

	# Clicking unobstructed realm space clears the current focus.
	# Do not emit anything when no generator is selected.
	if selected_generator_id != "":
		generator_selected.emit("")
		get_viewport().set_input_as_handled()


func set_selected_generator(generator_id: String) -> void:
	if selected_generator_id == generator_id:
		return

	selected_generator_id = generator_id
	if generator_selection_overlay != null:
		generator_selection_overlay.set_selected_generator(generator_id)

func _draw() -> void:
	realm_draw_controller.draw(self)

func _get_island_rect() -> Rect2:
	return realm_layout_geometry_controller.get_island_rect(
		size,
		ISLAND_CENTER_RATIO,
		ISLAND_BASE_SIZE,
		ISLAND_SCALE,
		realm_layout.island_aspect_ratio if realm_layout != null else 0.0,
		realm_layout.island_view_scale if realm_layout != null else 1.0,
		realm_layout.island_view_offset if realm_layout != null else Vector2.ZERO
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
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		realm_layout_editor_controller.handle_application_focus_lost()

func begin_prestige_destruction() -> void:
	crystallized_flame_visual_controller.begin_prestige_destruction()


func play_crystallization_event(
	crystals_created: float
) -> void:
	if not visual_effects_enabled:
		update_flame_visuals()
		return

	crystallized_flame_visual_controller.play_crystallization_event(
		self,
		state,
		crystals_created,
		_get_generator_position("infernal_forge"),
		false,
		visual_effect_quality
	)




func play_forge_level_reduction_event(
	generator_id: String,
	_previous_level: int,
	_new_level: int
) -> void:
	if not visual_effects_enabled or generator_id != "infernal_forge":
		return

	var effect := FORGE_LEVEL_REDUCTION_EFFECT.new() as Node2D
	effect.effect_quality = visual_effect_quality
	effect.position = _get_generator_position(generator_id)
	add_child(effect)


func play_critical_crystallization_event(crystals_created: float) -> void:
	if not visual_effects_enabled:
		update_flame_visuals()
		return

	crystallized_flame_visual_controller.play_crystallization_event(
		self,
		state,
		crystals_created,
		_get_generator_position("infernal_forge"),
		true,
		visual_effect_quality
	)


# ------------------------------------------------------------
# LAVA NETWORK
# ------------------------------------------------------------
