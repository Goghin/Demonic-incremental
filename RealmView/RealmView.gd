class_name RealmView
extends Control


var state: GameState
var generator_visual_renderer: GeneratorVisualRenderer = GeneratorVisualRenderer.new()
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

const MATTER_FURNACE_SIZE_MULTIPLIER: float = 1.4


var furnace_swirl_controller: FurnaceSwirlController = FurnaceSwirlController.new()
const THERMAL_FURNACE_ROTATION_SPEED: float = 1

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

	rebuild_realm(state.realm_layout)

func _setup_generator_layer() -> void:
	if is_instance_valid(generator_layer):
		return

	generator_layer = Node2D.new()
	generator_layer.name = "GeneratorLayer"
	generator_layer.z_index = 10
	add_child(generator_layer)


func _setup_braziers() -> void:
	for stat_name in BRAZIER_STATS:
		if braziers.has(stat_name):
			continue

		var brazier_instance: Brazier = (
			BRAZIER_SCENE.instantiate()
		)

		brazier_instance.set_stat(stat_name)

		add_child(brazier_instance)

		brazier_instance.z_index = 15

		brazier_instance.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		braziers[stat_name] = brazier_instance

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

	if generator_sprites.has("lava_mite_colony"):
		var lava_mite_sprite: AnimatedSprite2D = (
			generator_sprites["lava_mite_colony"]
			as AnimatedSprite2D
		)

		if lava_mite_sprite != null:
			lava_mite_sprite.stop()
			lava_mite_sprite.frame = 0
	
	if generator_sprites.has("matter_furnace"):
		var matter_furnace_sprite: AnimatedSprite2D = (
			generator_sprites["matter_furnace"]
			as AnimatedSprite2D
		)

		if matter_furnace_sprite != null:
			matter_furnace_sprite.stop()
			matter_furnace_sprite.frame = 0
		
	# ------------------------------------------------------------
	# Reset generator rotations
	# ------------------------------------------------------------

	for generator_id in generator_sprites:
		if (
			generator_id == "lava_mite_colony"
			or
			generator_id == "matter_furnace"
		):
			continue

		var sprite: Sprite2D = (
			generator_sprites[generator_id]
		)

		if sprite == null:
			continue

		sprite.rotation = 0.0

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
	_update_generator_animations(_delta)
	_update_molecular_agitation_sprites(_delta)
	_update_lava_lakes()
	_update_lava_flow_states()
	_update_furnace_swirl()
	_update_atomic_friction_particles()
	molecular_agitation_particle_controller.update(
		state.generators.get("thermal_furnace"),
		_get_generator_position("thermal_furnace")
	)
	_update_atomic_friction_animation(_delta)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_F2:
				realm_layout_mode = not realm_layout_mode
				dragging_object = ""

				if realm_layout_mode:
					print("=== REALM LAYOUT ===")

					print("--- Generators ---")

					for generator_id in realm_layout.generator_layout_positions:
						print(
							"Generator ",
							generator_id,
							" -> ",
							realm_layout.generator_layout_positions[
								generator_id
							]
						)

					print("--- Ash Piles ---")

					for i in range(realm_layout.ash_pile_layout_positions.size()):
						print(
							"Ash pile ",
							i + 1,
							" -> ",
							realm_layout.ash_pile_layout_positions[i]
						)

					print("--- Braziers ---")

					for stat_name in BRAZIER_STATS:
						if braziers.has(stat_name):
							print(
								"Brazier ",
								stat_name,
								" -> ",
								realm_layout.brazier_layout_positions[
									stat_name
								]
							)

					if not lava_lakes.is_empty():
						var main_lake: LavaLake = lava_lakes[0]
						print("MAIN LAKE FILL: ", main_lake.fill)
				
					print("====================")
					print(
						"Shift + Left Click = print normalized position"
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
					_print_layout_point(
						mouse_position
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


func _print_layout_point(
	mouse_position: Vector2
) -> void:
	var island_rect: Rect2 = _get_island_rect()

	var normalized_position: Vector2 = (
		(mouse_position - island_rect.position) /
		island_rect.size
	)

	print(
		"CLICKED POINT"
	)

	print(
		"Normalized -> Vector2(",
		"%.6f" % normalized_position.x,
		", ",
		"%.6f" % normalized_position.y,
		")"
	)

	print(
		"Island local -> Vector2(",
		"%.2f" % (mouse_position.x - island_rect.position.x),
		", ",
		"%.2f" % (mouse_position.y - island_rect.position.y)
	)

	print(
		"Screen/local -> ",
		mouse_position
	)


func _start_layout_drag(mouse_position: Vector2) -> void:
	# ------------------------------------------------------------
	# Ash piles
	# ------------------------------------------------------------

	for i in range(ash_piles.size()):
		var pile: Sprite2D = ash_piles[i]
		var pile_rect: Rect2 = Rect2(
			pile.position - Vector2(16.0, 16.0),
			Vector2(32.0, 32.0)
		)

		if pile_rect.has_point(mouse_position):
			dragging_object = "ash_pile:" + str(i)
			drag_offset = mouse_position - pile.position
			return

	# ------------------------------------------------------------
	# Braziers
	# ------------------------------------------------------------

	for stat_name in BRAZIER_STATS:
		if not braziers.has(stat_name):
			continue

		var brazier: Control = braziers[stat_name]

		var brazier_rect: Rect2 = Rect2(
			brazier.position - Vector2(32, 32),
			Vector2(64, 64)
		)

		if brazier_rect.has_point(mouse_position):
			dragging_object = "brazier:" + stat_name

			drag_offset = (
				mouse_position -
				brazier.position
			)

			return

	# ------------------------------------------------------------
	# Generators
	# ------------------------------------------------------------

	for generator_id in generator_hitboxes:
		var hitbox: Rect2 = generator_hitboxes[
			generator_id
		]

		if hitbox.has_point(mouse_position):
			dragging_object = generator_id

			var generator_position: Vector2 = (
				hitbox.position +
				hitbox.size * 0.5
			)

			drag_offset = (
				mouse_position -
				generator_position
			)

			return


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

	if realm_layout_mode:
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
	for stat_name in BRAZIER_STATS:
		if not braziers.has(stat_name):
			continue

		var normalized_position: Vector2 = (
			realm_layout.brazier_layout_positions[
				stat_name
			]
		)

		var brazier: Control = braziers[stat_name]

		brazier.position = (
			island_rect.position +
			island_rect.size *
			normalized_position
		)

func _draw_layout_overlay() -> void:
	draw_rect(
		Rect2(Vector2.ZERO, size),
		Color(1.0, 0.75, 0.20, 0.65),
		false,
		2.0
	)

	# ------------------------------------------------------------
	# Generator selection boxes
	# ------------------------------------------------------------

	for generator_id in generator_hitboxes:
		var hitbox: Rect2 = generator_hitboxes[
			generator_id
		]

		draw_rect(
			hitbox.grow(3.0),
			Color(1.0, 0.75, 0.20, 0.75),
			false,
			1.0
		)

	# ------------------------------------------------------------
	# Ash pile position markers
	# ------------------------------------------------------------

	for i in range(ash_piles.size()):
		var pile: Sprite2D = ash_piles[i]
		draw_circle(
			pile.position,
			12.0,
			Color(0.75, 0.75, 0.75, 0.2)
		)
		draw_circle(
			pile.position,
			14.0,
			Color(0.85, 0.75, 0.55, 0.85),
			false,
			2.0
		)
		draw_string(
			ThemeDB.fallback_font,
			pile.position + Vector2(4.0, -7.0),
			"A%d" % (i + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12,
			Color(1.0, 0.9, 0.7, 1.0)
		)

	# ------------------------------------------------------------
	# Brazier selection markers
	# ------------------------------------------------------------

	for stat_name in BRAZIER_STATS:
		if not braziers.has(stat_name):
			continue

		var brazier: Control = braziers[stat_name]
		var brazier_position: Vector2 = brazier.position

		draw_circle(
			brazier_position,
			30.0,
			Color(1.0, 0.75, 0.20, 0.15)
		)

		draw_circle(
			brazier_position,
			32.0,
			Color(1.0, 0.75, 0.20, 0.75),
			false,
			2.0
		)

		draw_line(
			brazier_position + Vector2(-42, 0),
			brazier_position + Vector2(42, 0),
			Color(1.0, 0.75, 0.20, 0.50),
			1.0
		)

		draw_line(
			brazier_position + Vector2(0, -42),
			brazier_position + Vector2(0, 42),
			Color(1.0, 0.75, 0.20, 0.50),
			1.0
		)




func _draw_generators() -> void:
	var active_generators: Array = []

	for generator_value in state.generators.values():
		var generator: Generator = generator_value
		var generator_id: String = generator.definition.id

		if generator.unlocked and (
			generator.level > 0 or
			generator_id == "infernal_forge"
		):
			active_generators.append(generator)

	generator_hitboxes.clear()

	var island_rect: Rect2 = _get_island_rect()
	var active_ids: Dictionary = {}

	var machine_size: float = 20.0

	for generator in active_generators:
		var generator_id: String = generator.definition.id

		active_ids[generator_id] = true

		if not realm_layout.generator_layout_positions.has(
			generator_id
		):
			continue

		var normalized_position: Vector2 = (
			realm_layout.generator_layout_positions[
				generator_id
			]
		)

		var generator_position: Vector2 = (
			island_rect.position +
			island_rect.size * normalized_position
		)

		var size_multiplier: float = 1.0

		if generator_id == "infernal_forge":
			size_multiplier = 1.8
		
		# ---------------------------------------------------------
		# Lava Mite Colony
		# ---------------------------------------------------------
		if generator_id == "lava_mite_colony":
			var animated_sprite: AnimatedSprite2D = (
				_get_lava_mite_sprite()
			)

			var frame_size: Vector2 = Vector2(
				256.0,
				256.0
			)

			# Level 1 = 80%
			# Level 21 = 100%
			# Above level 21 = diminishing growth
			var colony_size_multiplier: float = (
				_get_lava_mite_size_multiplier(
					generator.level
				)
			)

			var target_size: float = (
				machine_size *
				2.0 *
				size_multiplier *
				colony_size_multiplier
			)

			var texture_scale: float = min(
				target_size / max(frame_size.x, 1.0),
				target_size / max(frame_size.y, 1.0)
			)

			var draw_size: Vector2 = (
				frame_size * texture_scale
			)

			var hitbox: Rect2 = Rect2(
				generator_position - draw_size * 0.5,
				draw_size
			)

			generator_hitboxes[generator_id] = hitbox

			animated_sprite.position = generator_position
			animated_sprite.scale = Vector2(
				texture_scale,
				texture_scale
			)
			animated_sprite.z_index = 0
			animated_sprite.visible = true

			# Update animation speed based on level.
			_update_lava_mite_animation_speed(
				animated_sprite,
				generator.level
			)

			if generator.is_operating():
				animated_sprite.modulate = Color(
					1.0,
					1.0,
					1.0,
					0.75
				)

				if animated_sprite.animation != &"default":
					animated_sprite.animation = &"default"

				if not animated_sprite.is_playing():
					animated_sprite.play()
			else:
				animated_sprite.modulate = Color(
					0.70,
					0.70,
					0.70,
					1.0
				)

				if animated_sprite.is_playing():
					animated_sprite.pause()

			continue
			
		# ---------------------------------------------------------
		# Matter Furnace
		# ---------------------------------------------------------
		if generator_id == "matter_furnace":
			var animated_sprite: AnimatedSprite2D = (
				_get_matter_furnace_sprite()
			)

			var frame_size: Vector2 = Vector2(
				314.0,
				321.0
			)

			var target_size: float = (
				machine_size *
				2.0 *
				MATTER_FURNACE_SIZE_MULTIPLIER
			)

			var texture_scale: float = min(
				target_size / max(frame_size.x, 1.0),
				target_size / max(frame_size.y, 1.0)
			)

			var draw_size: Vector2 = (
				frame_size * texture_scale
			)

			var hitbox: Rect2 = Rect2(
				generator_position - draw_size * 0.5,
				draw_size
			)

			generator_hitboxes[generator_id] = hitbox

			animated_sprite.position = generator_position
			animated_sprite.scale = Vector2(
				texture_scale,
				texture_scale
			)

			animated_sprite.z_index = 0
			animated_sprite.visible = true

			if generator.is_operating():
				animated_sprite.modulate = Color(
					1.0,
					1.0,
					1.0,
					0.75
				)

				if animated_sprite.animation != &"default":
					animated_sprite.animation = &"default"

				if not animated_sprite.is_playing():
					animated_sprite.play()
			else:
				animated_sprite.modulate = Color(
					0.70,
					0.70,
					0.70,
					1.0
				)

				if animated_sprite.is_playing():
					animated_sprite.pause()

			continue
			
		if generator_id == "thermal_furnace":
			molecular_agitation_particle_controller.ensure_overlay(
				self,
				generator,
				generator_position
			)	
		# ---------------------------------------------------------
		# Normal generators
		# ---------------------------------------------------------
		var texture: Texture2D = _get_generator_texture(
			generator
		)

		if texture != null:
			var texture_size: Vector2 = texture.get_size()

			var target_size: float = (
				machine_size *
				2.0 *
				size_multiplier
			)

			var texture_scale: float = min(
				target_size / max(texture_size.x, 1.0),
				target_size / max(texture_size.y, 1.0)
			)

			var draw_size: Vector2 = (
				texture_size * texture_scale
			)

			var hitbox: Rect2 = Rect2(
				generator_position - draw_size * 0.5,
				draw_size
			)

			generator_hitboxes[generator_id] = hitbox

			var sprite: Sprite2D

			if generator_sprites.has(generator_id):
				sprite = generator_sprites[generator_id]
			else:
				sprite = Sprite2D.new()
				sprite.name = "Generator_" + generator_id
				generator_layer.add_child(sprite)
				generator_sprites[generator_id] = sprite

			sprite.z_index = 0
			sprite.texture = texture
			sprite.position = generator_position

			if generator_id == "atomic_friction":
				if not sprite.has_meta(
					"atomic_friction_base_scale"
				):
					sprite.set_meta(
						"atomic_friction_base_scale",
						Vector2(
							texture_scale,
							texture_scale
						)
					)
			else:
				sprite.scale = Vector2(
					texture_scale,
					texture_scale
				)

			sprite.visible = true

			if generator.is_operating():
				sprite.modulate = Color(
					1.0,
					1.0,
					1.0,
					0.75
				)
			else:
				sprite.modulate = Color(
					0.70,
					0.70,
					0.70,
					1.0
				)

		else:
			var fallback_size: float = (
				machine_size *
				size_multiplier
			)

			var fallback_rect: Rect2 = Rect2(
				generator_position - Vector2(
					fallback_size,
					fallback_size
				),
				Vector2(
					fallback_size * 2.0,
					fallback_size * 2.0
				)
			)

			generator_hitboxes[generator_id] = fallback_rect

	# Hide normal generators that are no longer active.
	for generator_id in generator_sprites:
		if (
			generator_id == "lava_mite_colony"
			or
			generator_id == "matter_furnace"
		):
			continue

		if not active_ids.has(generator_id):
			var sprite: Sprite2D = generator_sprites[
				generator_id
			]
			sprite.visible = false

	# Hide the lava mite colony when it is no longer active.
	if generator_sprites.has("lava_mite_colony"):
		var lava_mite_sprite: AnimatedSprite2D = (
			generator_sprites[
				"lava_mite_colony"
			] as AnimatedSprite2D
		)

		if lava_mite_sprite != null:
			lava_mite_sprite.visible = (
				active_ids.has("lava_mite_colony")
			)

	# Hide the matter furnace when it is no longer active.
	if generator_sprites.has("matter_furnace"):
		var matter_furnace_sprite: AnimatedSprite2D = (
			generator_sprites[
				"matter_furnace"
			] as AnimatedSprite2D
		)

		if matter_furnace_sprite != null:
			matter_furnace_sprite.visible = (
				active_ids.has("matter_furnace")
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

func _get_generator_texture(
	generator: Generator
) -> Texture2D:
	return generator_visual_renderer.get_texture(generator)


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
	var island: Sprite2D = get_node_or_null("Island") as Sprite2D

	if island == null:
		return

	if realm_layout == null:
		return

	var island_rect: Rect2 = _get_island_rect()

	var island_texture: Texture2D = (
		realm_layout.island_texture
	)

	if island_texture == null:
		return

	island.texture = island_texture
	island.position = (
		island_rect.position +
		island_rect.size * 0.5
	)
	island.scale = (
		island_rect.size /
		island_texture.get_size()
	)
	island.z_index = 5

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
		
		
func _update_generator_animations(delta: float) -> void:
	if state == null:
		return

	if not generator_sprites.has("thermal_furnace"):
		return

	var furnace: Generator = state.generators.get(
		"thermal_furnace"
	)

	if furnace == null:
		return

	var sprite: Sprite2D = generator_sprites["thermal_furnace"]
	thermal_furnace_animation_controller.update(
		self,
		furnace,
		sprite,
		delta
	)

func _update_molecular_agitation_sprites(delta: float) -> void:
	if state == null:
		return

	if not generator_sprites.has("molecular_agitation"):
		molecular_agitation_sprite_controller.hide()
		return

	var generator: Generator = state.generators.get(
		"molecular_agitation"
	)
	var sprite: Sprite2D = generator_sprites["molecular_agitation"]

	molecular_agitation_sprite_controller.update(
		self,
		generator,
		sprite,
		delta
	)


func _update_furnace_swirl() -> void:
	if state == null:
		return

	if not generator_sprites.has("molecular_agitation"):
		return

	var furnace: Generator = state.generators.get(
		"molecular_agitation"
	)

	if furnace == null:
		return

	var sprite: Sprite2D = generator_sprites["molecular_agitation"]

	furnace_swirl_controller.update(
		self,
		furnace,
		sprite
	)


func _update_atomic_friction_particles() -> void:
	if state == null:
		return

	if not generator_sprites.has("atomic_friction"):
		return

	var generator: Generator = state.generators.get(
		"atomic_friction"
	)

	if generator == null:
		return

	var sprite: Sprite2D = generator_sprites[
		"atomic_friction"
	]

	atomic_friction_particle_controller.update(
		self,
		generator,
		sprite
	)


func _update_atomic_friction_animation(delta: float) -> void:
	if state == null:
		return

	if not generator_sprites.has("atomic_friction"):
		return

	var generator: Generator = state.generators.get(
		"atomic_friction"
	)

	if generator == null:
		return

	var sprite: Sprite2D = generator_sprites[
		"atomic_friction"
	]

	atomic_friction_animation_controller.update(
		generator,
		sprite,
		delta
	)

func _get_lava_mite_sprite() -> AnimatedSprite2D:
	return generator_visual_renderer.get_lava_mite_sprite(
		generator_layer,
		generator_sprites
	)


func _get_matter_furnace_sprite() -> AnimatedSprite2D:
	return generator_visual_renderer.get_matter_furnace_sprite(
		generator_layer,
		generator_sprites
	)


func _get_lava_mite_size_multiplier(level: int) -> float:
	return generator_visual_renderer.get_lava_mite_size_multiplier(level)


func _update_lava_mite_animation_speed(
	animated_sprite: AnimatedSprite2D,
	level: int
) -> void:
	generator_visual_renderer.update_lava_mite_animation_speed(
		animated_sprite,
		level
	)

