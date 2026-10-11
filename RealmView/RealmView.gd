class_name RealmView
extends Control


var state: GameState
var generator_visual_renderer: GeneratorVisualRenderer = GeneratorVisualRenderer.new()
var generator_drawing_controller: GeneratorDrawingController = GeneratorDrawingController.new()
var generator_animation_controller: GeneratorAnimationController = GeneratorAnimationController.new()
var lava_mite_visual_controller: LavaMiteVisualController = LavaMiteVisualController.new()
var matter_furnace_visual_controller: MatterFurnaceVisualController = MatterFurnaceVisualController.new()
var lava_flow_state_controller: LavaFlowStateController = LavaFlowStateController.new()
var lava_lake_state_controller: LavaLakeStateController = LavaLakeStateController.new()
var lava_lake_visual_controller: LavaLakeVisualController = LavaLakeVisualController.new()
var lava_network_controller: LavaNetworkController = LavaNetworkController.new()
var thermal_furnace_animation_controller: ThermalFurnaceAnimationController = ThermalFurnaceAnimationController.new()
var ash_renderer: AshContaminationRenderer
var ash_piles: Array[Sprite2D] = []
var generator_sprites: Dictionary = {}
var generator_layer: Node2D

var ash_pile_renderer: AshPileRenderer = AshPileRenderer.new()
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

var lava_flows: Array[LavaFlow] = []
var lava_falls: Array[LavaFall] = []
var lava_lakes: Array[LavaLake] = []

const CRYSTAL_BASE_SCALE: float = 0.08

const REALM_VISUAL_SCALE: float = 1.0
const REALM_VISUAL_OFFSET: Vector2 = Vector2(0.0, 0.0)
const ISLAND_BASE_SIZE: Vector2 = Vector2(418.0, 156.0)
const ISLAND_SCALE: float = 2.0


const LAVA_EDGE_VARIATION: float = 0.55

var realm_layout: Resource
var island: Sprite2D

var default_realm_layout = preload("res://RealmView/Layouts/TestRealmLayout.gd").new()

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
	_setup_generator_layer()

	scale = Vector2(
		REALM_VISUAL_SCALE,
		REALM_VISUAL_SCALE
	)

	pivot_offset = size * 0.5
	position = REALM_VISUAL_OFFSET

	_setup_braziers()
	_setup_realm_layout_overlay()

	rebuild_realm(state.realm_layout)

func _setup_generator_layer() -> void:
	generator_layer = generator_visual_renderer.setup_layer(
		self,
		generator_layer
	)


func _setup_realm_layout_overlay() -> void:
	realm_layout_overlay_renderer.name = "RealmLayoutOverlayRenderer"
	realm_layout_overlay_renderer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	realm_layout_overlay_renderer.z_index = 100
	realm_layout_overlay_renderer.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	add_child(realm_layout_overlay_renderer)


func _setup_braziers() -> void:
	brazier_visual_controller.setup(
		self,
		braziers,
		BRAZIER_STATS,
		BRAZIER_SCENE
	)

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
	# Remove old lava network
	# ------------------------------------------------------------

	for flow in lava_flows:
		if is_instance_valid(flow):
			flow.queue_free()

	for fall in lava_falls:
		if is_instance_valid(fall):
			fall.queue_free()

	for lake in lava_lakes:
		if is_instance_valid(lake):
			lake.queue_free()

	lava_flows.clear()
	lava_falls.clear()
	lava_lakes.clear()

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

	_update_island_sprite()
	_setup_ash_piles()

	_create_lava_network()

	_create_lava_lakes()

	_update_lava_network_positions()

	_update_lava_lake_positions()

	_draw_generators()

	# Force brazier positions to update immediately.
	var island_rect: Rect2 = _get_island_rect()

	_initialize_brazier_positions(
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

	_update_lava_flow_states()

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


func _process(_delta: float) -> void:
	if state == null:
		return

	var current_flames: float = state.get_resource_amount(
		ResourceIds.CRYSTALIZED_FLAME
	)

	if not is_equal_approx(
		current_flames,
		last_crystallized_flame_amount
	):
		last_crystallized_flame_amount = current_flames
		update_flame_visuals()

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
	_update_lava_lakes()
	_update_lava_flow_states()
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
						lava_lakes
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

		_update_layout_drag(
			get_local_mouse_position()
		)


func _start_layout_drag(mouse_position: Vector2) -> void:
	var drag_result: Dictionary = realm_layout_editor_controller.find_drag_target(
		mouse_position,
		ash_piles,
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

	var center: Vector2 = size * Vector2(0.68, 0.66)

	var realm: RealmConfiguration = (
		state.realm_configuration
	)

	for stat_name in BRAZIER_STATS:
		if not braziers.has(stat_name):
			continue

		var brazier: Brazier = braziers[stat_name]

		brazier.set_stat_value(
			realm.get_stat_value(stat_name)
		)

	var ash: float = state.get_resource_amount(
		ResourceIds.ASH
	)
	_update_ash_piles(ash)

	# ------------------------------------------------------------
	# Neutral realm dimensions
	# ------------------------------------------------------------

	var realm_scale: float = 1.0
	var density_factor: float = 1.0

	var sx: float = (
		190.0 *
		realm_scale *
		density_factor
	)

	var sy: float = (
		78.0 *
		realm_scale *
		density_factor
	)

	# ------------------------------------------------------------
	# Background
	# ------------------------------------------------------------

	draw_rect(
		Rect2(Vector2.ZERO, size),
		Color(0.04, 0.029, 0.074, 1.0)
	)

	# ------------------------------------------------------------
	# Ambient haze
	# ------------------------------------------------------------

	draw_circle(
		center + Vector2(0, -25),
		250.0,
		Color(0.16, 0.07, 0.22, 0.12)
	)

	# ------------------------------------------------------------
	# Distant realm particles
	# ------------------------------------------------------------

	var particle_count: int = 65

	for i in range(particle_count):
		var angle: float = float(i) * 2.399

		var distance: float = 120.0 + fmod(
			float(i * 73),
			360.0
		)

		var particle_position: Vector2 = (
			center +
			Vector2(
				cos(angle) * distance,
				sin(angle) * distance * 0.65
			)
		)

		var particle_size: float = 0.4 + fmod(
			float(i),
			1.6
		)

		draw_circle(
			particle_position,
			particle_size,
			Color(0.55, 0.36, 0.65, 0.30)
		)

	var island_rect: Rect2 = _get_island_rect()

	# ------------------------------------------------------------
	# Floating island
	# ------------------------------------------------------------

	_initialize_brazier_positions(
		island_rect
	)

	# ------------------------------------------------------------
	# Generators
	# ------------------------------------------------------------

	_draw_generators()

	_draw_forge_active_glow()

	# ------------------------------------------------------------
	# Ash
	# ------------------------------------------------------------

	_update_ash_visuals(
		center,
		sx,
		ash
	)

	# ------------------------------------------------------------
	# Layout mode
	# ------------------------------------------------------------

	_draw_layout_overlay()


func _get_island_rect() -> Rect2:
	var center: Vector2 = size * Vector2(0.68, 0.66)
	var island_size: Vector2 = ISLAND_BASE_SIZE * ISLAND_SCALE

	return Rect2(
		center - island_size * 0.5,
		island_size
	)

func _initialize_brazier_positions(
	island_rect: Rect2
) -> void:
	brazier_visual_controller.position_braziers(
		braziers,
		BRAZIER_STATS,
		realm_layout,
		island_rect
	)

func _draw_layout_overlay() -> void:
	realm_layout_overlay_renderer.update_overlay(
		realm_layout_mode,
		generator_hitboxes,
		ash_piles,
		braziers,
		BRAZIER_STATS
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



func _setup_ash_piles() -> void:
	ash_piles = ash_pile_renderer.setup(
		self,
		ash_piles,
		realm_layout
	)


func _update_ash_piles(ash: float) -> void:
	ash_pile_renderer.update(
		ash_piles,
		realm_layout.ash_pile_layout_positions,
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
		ash_renderer.name = "AshContaminationRenderer"
		ash_renderer.z_index = 10
		add_child(ash_renderer)

	ash_renderer.update_visuals(center, sx, ash)


func _update_layout_drag(
	mouse_position: Vector2
) -> void:
	if dragging_object == "":
		return

	# ------------------------------------------------------------
	# Ash pile
	# ------------------------------------------------------------

	if dragging_object.begins_with("ash_pile:"):
		var pile_index: int = int(dragging_object.substr(9))
		if pile_index >= 0 and pile_index < realm_layout.ash_pile_layout_positions.size():
			var new_position: Vector2 = mouse_position - drag_offset
			var island_rect: Rect2 = _get_island_rect()
			var normalized_position: Vector2 = (
				(new_position - island_rect.position) /
				island_rect.size
			)
			normalized_position.x = clamp(normalized_position.x, 0.0, 1.0)
			normalized_position.y = clamp(normalized_position.y, 0.0, 1.0)
			realm_layout.ash_pile_layout_positions[pile_index] = normalized_position
			_update_ash_piles(
				state.get_resource_amount(ResourceIds.ASH)
			)
			queue_redraw()
		return

	# ------------------------------------------------------------
	# Brazier
	# ------------------------------------------------------------

	if dragging_object.begins_with("brazier:"):
		var stat_name: String = (
			dragging_object.substr(8)
		)

		if braziers.has(stat_name):
			var new_position: Vector2 = (
				mouse_position -
				drag_offset
			)

			var island_rect: Rect2 = (
				_get_island_rect()
			)

			var normalized_position: Vector2 = (
				(new_position - island_rect.position) /
				island_rect.size
			)

			normalized_position.x = clamp(
				normalized_position.x,
				0.0,
				1.0
			)

			normalized_position.y = clamp(
				normalized_position.y,
				0.0,
				1.0
			)

			realm_layout.brazier_layout_positions[
				stat_name
			] = normalized_position

			braziers[stat_name].position = (
				island_rect.position +
				island_rect.size *
				normalized_position
			)

			queue_redraw()

			return

	# ------------------------------------------------------------
	# Generator
	# ------------------------------------------------------------

	if realm_layout.generator_layout_positions.has(
		dragging_object
	):
		var new_position: Vector2 = (
			mouse_position -
			drag_offset
		)

		var island_rect: Rect2 = (
			_get_island_rect()
		)

		var normalized_position: Vector2 = (
			(new_position - island_rect.position) /
			island_rect.size
		)

		normalized_position.x = clamp(
			normalized_position.x,
			0.0,
			1.0
		)

		normalized_position.y = clamp(
			normalized_position.y,
			0.0,
			1.0
		)

		realm_layout.generator_layout_positions[
			dragging_object
		] = normalized_position

		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_lava_network_positions()
		_update_island_sprite()
		_update_lava_lake_positions()


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

	if crystals_created <= 0.0:
		return

	var forge_position: Vector2 = (
		_get_generator_position(
			"infernal_forge"
		)
	)

	var old_count: int = (
		crystallized_flames.size()
	)

	update_flame_visuals()

	var new_count: int = (
		crystallized_flames.size()
	)

	if new_count <= old_count:
		return

	for i in range(old_count, new_count):
		var crystal: CrystallizedFlame = (
			crystallized_flames[i]
		)

		var target_position: Vector2 = (
			crystal.base_position
		)

		crystal.scale = Vector2.ZERO

		_play_crystal_stream(
			forge_position,
			target_position,
			crystal
		)


func _play_crystal_stream(
	from_position: Vector2,
	target_position: Vector2,
	crystal: CrystallizedFlame
) -> void:
	crystallization_stream_controller.play(
		self,
		from_position,
		target_position,
		crystal,
		CRYSTAL_BASE_SCALE
	)



func _draw_forge_active_glow() -> void:
	if state == null:
		return

	forge_activity_visual_controller.update(
		self,
		state.generators.get("infernal_forge"),
		_get_generator_position("infernal_forge")
	)


# ------------------------------------------------------------
# LAVA NETWORK
# ------------------------------------------------------------



func _create_lava_network() -> void:
	lava_network_controller.create_network(
		self,
		realm_layout,
		_get_island_rect(),
		lava_flows,
		lava_falls,
		LAVA_FLOW_SCENE,
		LAVA_FALL_SCENE
	)


func _update_lava_network_positions() -> void:
	lava_network_controller.update_positions(
		realm_layout,
		_get_island_rect(),
		lava_flows,
		lava_falls
	)


func _update_island_sprite() -> void:
	island_visual_controller.update(
		self,
		realm_layout,
		_get_island_rect()
	)

func _create_lava_lakes() -> void:
	lava_lake_visual_controller.create_lakes(
		self,
		state,
		realm_layout,
		_get_island_rect(),
		LAVA_LAKE_SCENE,
		lava_lakes
	)


func _update_lava_lakes() -> void:
	lava_lake_state_controller.update(
		state,
		realm_layout,
		lava_lakes
	)


func _update_lava_lake_positions() -> void:
	lava_lake_visual_controller.update_positions(
		_get_island_rect(),
		lava_lakes
	)



func _update_lava_flow_states() -> void:
	lava_flow_state_controller.update(
		state,
		realm_layout,
		lava_lakes,
		lava_flows,
		lava_falls
	)
		
		




