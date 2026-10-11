class_name RealmView
extends Control

var state: GameState
var generator_visual_renderer: GeneratorVisualRenderer = GeneratorVisualRenderer.new()
var generator_drawing_controller: GeneratorDrawingController = GeneratorDrawingController.new()
var generator_animation_controller: GeneratorAnimationController = GeneratorAnimationController.new()
var lava_mite_visual_controller: LavaMiteVisualController = LavaMiteVisualController.new()
var matter_furnace_visual_controller: MatterFurnaceVisualController = MatterFurnaceVisualController.new()
var lava_realm_visual_controller: LavaRealmVisualController = LavaRealmVisualController.new()
var thermal_furnace_animation_controller: ThermalFurnaceAnimationController = ThermalFurnaceAnimationController.new()
var ash_renderer: AshContaminationRenderer
var ash_visual_controller: AshVisualController = AshVisualController.new()
var generator_sprites: Dictionary = {}
var generator_layer: Node2D

var molecular_agitation_sprite_controller: MolecularAgitationSpriteController = MolecularAgitationSpriteController.new()

var atomic_friction_particle_controller: AtomicFrictionParticleController = AtomicFrictionParticleController.new()

var furnace_swirl_controller: FurnaceSwirlController = FurnaceSwirlController.new()

var atomic_friction_animation_controller: AtomicFrictionAnimationController = AtomicFrictionAnimationController.new()

var molecular_agitation_particle_controller: MolecularAgitationParticleController = MolecularAgitationParticleController.new()

var braziers: Dictionary = {}

var crystallized_flames: Array[CrystallizedFlame] = []
var crystallized_flame_values: Array[float] = []
var crystal_renderer: CrystalRenderer = CrystalRenderer.new()
var crystallization_stream_controller: CrystallizationStreamController = CrystallizationStreamController.new()
var last_crystallized_flame_amount: float = -1.0


const REALM_VISUAL_SCALE: float = 1.0
const REALM_VISUAL_OFFSET: Vector2 = Vector2(0.0, 0.0)
const ISLAND_BASE_SIZE: Vector2 = Vector2(418.0, 156.0)
const ISLAND_SCALE: float = 2.0
const ISLAND_CENTER_RATIO: Vector2 = Vector2(0.68, 0.66)
const ASH_VISUAL_RADIUS: float = 190.0

var realm_layout: Resource

const LAVA_LAKE_SCENE = preload(
	"res://RealmView/LavaLake.tscn"
)

const LAVA_FLOW_SCENE = preload(
	"res://RealmView/lavaflow.tscn"
)

const LAVA_FALL_SCENE = preload(
	"res://RealmView/lavafall.tscn"
)

var realm_layout_mode: bool = false
var dragging_object: String = ""
var drag_offset: Vector2 = Vector2.ZERO

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
	if state == null:
		return

	if new_layout == null:
		push_warning(
			"RealmView: Cannot rebuild realm without a RealmLayout."
		)
		return

	realm_layout = new_layout

	# ------------------------------------------------------------
	# Reset generator visual effects
	# ------------------------------------------------------------

	thermal_furnace_animation_controller.reset()

	atomic_friction_particle_controller.reset()

	forge_activity_visual_controller.reset()

	furnace_swirl_controller.reset()

	molecular_agitation_particle_controller.reset()
	# ------------------------------------------------------------
	# Reset lava mite  and matter furnace animation
	# ------------------------------------------------------------

	lava_mite_visual_controller.reset(generator_sprites)

	matter_furnace_visual_controller.reset(generator_sprites)

	# ------------------------------------------------------------
	# Reset generator rotations
	# ------------------------------------------------------------

	generator_visual_renderer.reset_generator_rotations(
		generator_sprites
	)

	generator_visual_renderer.clear_cache()

	# ------------------------------------------------------------
	# Build the new realm
	# ------------------------------------------------------------

	island_visual_controller.update(
		self,
		realm_layout,
		_get_island_rect()
	)
	ash_visual_controller.setup(self, realm_layout)

	lava_realm_visual_controller.create_network(
		self,
		realm_layout,
		_get_island_rect(),
		LAVA_FLOW_SCENE,
		LAVA_FALL_SCENE
	)
	lava_realm_visual_controller.create_lakes(
		self,
		state,
		realm_layout,
		_get_island_rect(),
		LAVA_LAKE_SCENE
	)
	lava_realm_visual_controller.update_positions(
		realm_layout,
		_get_island_rect()
	)

	_draw_generators()

	# Force brazier positions to update immediately.
	var island_rect: Rect2 = _get_island_rect()

	brazier_visual_controller.position_braziers(
		braziers,
		BRAZIER_STATS,
		realm_layout,
		island_rect
	)

	# ------------------------------------------------------------
	# Crystallized flame visuals
	# ------------------------------------------------------------

	last_crystallized_flame_amount = -1.0
	update_flame_visuals()

	# ------------------------------------------------------------
	# Initial lava state
	# ------------------------------------------------------------

	lava_realm_visual_controller.update_flow_states(
		state,
		realm_layout
	)

	queue_redraw()

func update_flame_visuals() -> void:
	if state == null:
		return

	var total_flames: float = state.get_resource_amount(
		ResourceIds.CRYSTALIZED_FLAME
	)

	crystal_renderer.update(
		self,
		crystallized_flames,
		crystallized_flame_values,
		total_flames
	)

func _update_crystallized_flame_visuals_if_needed() -> void:
	var current_flames: float = state.get_resource_amount(
		ResourceIds.CRYSTALIZED_FLAME
	)

	if is_equal_approx(
		current_flames,
		last_crystallized_flame_amount
	):
		return

	last_crystallized_flame_amount = current_flames
	update_flame_visuals()


func _process(_delta: float) -> void:
	if state == null:
		return

	_update_crystallized_flame_visuals_if_needed()

	forge_activity_visual_controller.advance(_delta)
	generator_animation_controller.update_phase(
		&"early",
		self,
		state,
		generator_sprites,
		_delta,
		thermal_furnace_animation_controller,
		molecular_agitation_sprite_controller,
		furnace_swirl_controller,
		atomic_friction_particle_controller,
		atomic_friction_animation_controller
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
		_delta,
		thermal_furnace_animation_controller,
		molecular_agitation_sprite_controller,
		furnace_swirl_controller,
		atomic_friction_particle_controller,
		atomic_friction_animation_controller
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
		_delta,
		thermal_furnace_animation_controller,
		molecular_agitation_sprite_controller,
		furnace_swirl_controller,
		atomic_friction_particle_controller,
		atomic_friction_animation_controller
	)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_F2:
				realm_layout_mode = not realm_layout_mode
				dragging_object = ""

				if realm_layout_mode:
					realm_layout_debug_controller.print_layout_details(
						realm_layout,
						braziers,
						BRAZIER_STATS,
						lava_realm_visual_controller.lakes
					)

				queue_redraw()

			return

	if not realm_layout_mode:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:

				var mouse_position: Vector2 = (
					get_local_mouse_position()
				)

				if event.shift_pressed:
					realm_layout_debug_controller.print_layout_point(
						mouse_position,
						_get_island_rect()
					)
					return

				_start_layout_drag(
					mouse_position
				)

			else:
				dragging_object = ""

	elif event is InputEventMouseMotion:
		if dragging_object == "":
			return

		realm_layout_editor_controller.update_drag(
			get_local_mouse_position(),
			dragging_object,
			drag_offset,
			realm_layout,
			braziers,
			_get_island_rect(),
			state.get_resource_amount(ResourceIds.ASH),
			Callable(self, "_update_ash_piles"),
			Callable(self, "queue_redraw")
		)

func _start_layout_drag(mouse_position: Vector2) -> void:
	var drag_result: Dictionary = realm_layout_editor_controller.find_drag_target(
		mouse_position,
		ash_visual_controller.piles,
		braziers,
		BRAZIER_STATS,
		generator_hitboxes,
		dragging_object,
		drag_offset
	)

	dragging_object = drag_result["object"]
	drag_offset = drag_result["offset"]

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

	_update_ash_visuals(
		center,
		ASH_VISUAL_RADIUS,
		ash
	)

	# ------------------------------------------------------------
	# Layout mode
	# ------------------------------------------------------------

	realm_layout_overlay_renderer.update_overlay(
		realm_layout_mode,
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

func _update_ash_visuals(
	center: Vector2,
	sx: float,
	ash: float
) -> void:
	if ash_renderer == null:
		ash_renderer = AshContaminationRenderer.new()
		ash_renderer.attach_to(self)

	ash_renderer.update_visuals(center, sx, ash)

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
	if crystallized_flames.is_empty():
		return

	print(
		"BEGIN PRESTIGE DESTRUCTION: ",
		crystallized_flames.size(),
		" crystals"
	)

	var first_index: int = randi_range(
		0,
		crystallized_flames.size() - 1
	)

	var first_crystal: CrystallizedFlame = (
		crystallized_flames[first_index]
	)

	print(
		"Starting chain reaction with crystal ",
		first_index,
		" at ",
		first_crystal.position
	)

	first_crystal.begin_destruction(0.0)

func play_crystallization_event(
	crystals_created: float
) -> void:
	if state == null:
		return

	crystallization_stream_controller.play_crystallization_event(
		self,
		crystals_created,
		_get_generator_position("infernal_forge"),
		crystallized_flames,
		crystallized_flame_values,
		state.get_resource_amount(ResourceIds.CRYSTALIZED_FLAME),
		crystal_renderer
	)

# ------------------------------------------------------------
# LAVA NETWORK
# ------------------------------------------------------------


