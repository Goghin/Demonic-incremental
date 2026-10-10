class_name RealmView
extends Control


class AtomicFrictionParticleOverlay extends Node2D:
	var time: float = 0.0
	var active: bool = false
	var generator_level: int = 1

	func _process(delta: float) -> void:
		time += delta
		queue_redraw()

	func _draw() -> void:
		if not active:
			return


		var level: float = float(max(generator_level, 1))



		# Particle count increases with level, with diminishing returns.
		var particle_count: int = int(
			2.0 + min(max(level - 1.0, 0.0) * 14.0 / 99.0, 14.0)
		)

		# Higher levels make particles vibrate faster.
		var intensity: float = 1.0 + 0.05 * sqrt(level - 1.0)

		for i in range(particle_count):
			var seed: float = float(i) * 17.31

			var phase: float = (
				time * (5.0 + fmod(seed, 4.0)) * intensity
				+ seed
			)

			var cycle: float = fmod(
				time * (0.65 + fmod(seed, 0.4)) * intensity
				+ seed,
				1.0
			)

			# Particles remain clustered around the machine.
			var radius: float = (
				3.0
				+ fmod(seed * 2.7, 7.0)
				+ sin(phase) * (1.5 + 0.25 * (intensity - 1.0))
			)

			var angle: float = (
				seed + sin(phase * 0.7) * 0.8
			)

			var particle_position: Vector2 = Vector2(
				cos(angle) * radius,
				sin(angle) * radius * 0.75
			)

			# Particle brightness increases slightly with level.
			var alpha: float = clamp(
				0.45
				+ 0.35 * (0.5 + 0.5 * sin(phase))
				+ 0.08 * (intensity - 1.0),
				0.0,
				1.0
			)

			var particle_size: float = (
				0.3 * min(1.0 + 0.08 * sqrt(level - 1.0), 1.2)
			)

			draw_circle(
				particle_position,
				particle_size,
				Color(0.05, 0.85, 0.78, alpha)
			)

			# Sparks escape more often as the machine levels up.
			var spark_threshold: float = max(
				0.62,
				0.78 - 0.025 * sqrt(level - 1.0)
			)

			if cycle > spark_threshold:
				var spark_progress: float = (
					(cycle - spark_threshold)
					/ (1.0 - spark_threshold)
				)

				var spark_direction: Vector2 = Vector2(
					cos(angle + sin(seed) * 0.5),
					sin(angle + sin(seed) * 0.5)
				)

				var spark_start: Vector2 = (
					particle_position + spark_direction * 2.0
				)

				var spark_length: float = (
					2.0 + spark_progress * 5.0
				) * min(intensity, 2.0)

				var spark_end: Vector2 = (
					spark_start + spark_direction * spark_length
				)

				var spark_alpha: float = (
					1.0 - spark_progress
				)

				draw_line(
					spark_start,
					spark_end,
					Color(0.35, 0.95, 1.0, spark_alpha),
					1.0
				)

				draw_circle(
					spark_end,
					0.65 * min(intensity, 1.5),
					Color(0.8, 1.0, 1.0, spark_alpha)
				)

class ForgeGlowOverlay extends Node2D:
	var glow_radius: float = 0.0
	var glow_alpha: float = 0.0
	var pulse: float = 0.0
	var core_alpha: float = 1.0

	func _draw() -> void:
		draw_circle(
			Vector2.ZERO,
			glow_radius,
			Color(
				1.0,
				0.25,
				0.02,
				glow_alpha
			)
		)

		draw_circle(
			Vector2.ZERO,
			glow_radius * 0.35,
			Color(
				1.0,
				0.55,
				0.08,
				glow_alpha * 1.5
			)
		)

		draw_circle(
			Vector2.ZERO,
			1.0 + pulse * 3.0,
			Color(
				1.0,
				0.85,
				0.35,
				core_alpha
			)
		)

class FurnaceSwirlOverlay extends Node2D:
	var time: float = 0.0
	var active: bool = false
	var speed_multiplier: float = 1.0

	func _process(delta: float) -> void:
		time += delta
		queue_redraw()

	func _draw() -> void:
		if not active:
			return

		var center := Vector2.ZERO

		for i in range(5):
			var phase: float = (
				time *
				(1.4 + i * 0.18) *
				speed_multiplier +
				i * TAU / 5.0
			)

			var cycle: float = fmod(
				time * 0.7 * speed_multiplier +
				i * 0.23,
				1.0
			)
			var inward: float = pow(cycle, 2.2)
			var radius: float = lerp(13.0, 2.5, inward)

			var orb_position := center + Vector2(
				cos(phase),
				sin(phase)
			) * radius

			orb_position += Vector2(
				sin(time * 3.0 + i * 2.1),
				cos(time * 2.4 + i * 1.7)
			) * 1.5

			var alpha: float = 0.7 * (1.0 - inward * 0.75)

			draw_circle(
				orb_position,
				1.8,
				Color(1.0, 0.35, 0.04, alpha)
			)

			draw_circle(
				orb_position,
				0.8,
				Color(1.0, 0.85, 0.3, alpha)
			)

class ForgeSparkOverlay extends Node2D:
	var time: float = 0.0
	var active: bool = false

	func _process(delta: float) -> void:
		time += delta
		queue_redraw()

	func _draw() -> void:
		if not active:
			return

		for i in range(11):
			var seed: float = float(i) * 17.31

			var cycle: float = fmod(
				time * (0.35 + fmod(seed, 0.25)) +
				seed,
				1.0
			)

			# Evenly distributed directions around the forge.
			var angle: float = (
				float(i) * TAU / 9.0 +
				sin(seed) * 0.25
			)

			var distance: float = lerp(
				2.0,
				24.0,
				cycle
			)

			# Slight irregularity in the outward path.
			var wobble: float = sin(
				time * 5.0 +
				seed
			) * 1.0

			var spark_position := Vector2(
				cos(angle),
				sin(angle)
			) * (distance + wobble)

			var alpha: float = (
				sin(cycle * PI) *
				0.75
			)

			var spark_size: float = (
				0.45 +
				fmod(seed, 0.35)
			)

			draw_circle(
				spark_position,
				spark_size,
				Color(
					1.0,
					0.65,
					0.15,
					alpha
				)
			)

var state: GameState
var generator_textures: Dictionary = {}
var generator_sprites: Dictionary = {}
var furnace_inner_sprite: Sprite2D

var atomic_friction_particles: Node2D

const LAVA_MITE_ANIMATION_PATH: String = (
	"res://Generators/GeneratorDefinitions/Lava_Mite_Colony_Animated.png"
)

const LAVA_MITE_ANIMATION_HFRAMES: int = 4
const LAVA_MITE_ANIMATION_VFRAMES: int = 4
const LAVA_MITE_ANIMATION_FPS: float = 4.0

const MATTER_FURNACE_ANIMATION_PATH: String = (
	"res://Generators/GeneratorDefinitions/matter furnace_animated.png"
)

const MATTER_FURNACE_ANIMATION_HFRAMES: int = 4
const MATTER_FURNACE_ANIMATION_VFRAMES: int = 4
const MATTER_FURNACE_ANIMATION_FPS: float = 10.0
const MATTER_FURNACE_SIZE_MULTIPLIER: float = 1.4

var forge_glow_overlay: Node2D
var forge_spark_overlay: Node2D

var furnace_swirl_overlay: Node2D
const THERMAL_FURNACE_ROTATION_SPEED: float = 1

const ATOMIC_FRICTION_BASE_ROTATION_SPEED: float = -0.45
const ATOMIC_FRICTION_BASE_PULSE_SPEED: float = 1.2

const ATOMIC_FRICTION_ROTATION_LEVEL_BONUS: float = 0.12
const ATOMIC_FRICTION_PULSE_LEVEL_BONUS: float = 0.20

var atomic_friction_time: float = 0.0

var molecular_agitation_overlay: MolecularAgitationParticleOverlay

var braziers: Dictionary = {}

var crystallized_flames: Array[CrystallizedFlame] = []
var crystallized_flame_values: Array[float] = []
var last_crystallized_flame_amount: float = -1.0

var lava_flows: Array[LavaFlow] = []
var lava_falls: Array[LavaFall] = []
var lava_lakes: Array[LavaLake] = []

const CRYSTAL_BASE_SCALE: float = 0.08
const CRYSTAL_CENTER: Vector2 = Vector2(0.68, 0.33)

const MAX_VISIBLE_CRYSTALS: int = 25

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

var forge_glow_time: float = 0.0

const FORGE_ACTIVE_GLOW_RADIUS: float = 15.0
const FORGE_ACTIVE_GLOW_ALPHA: float = 0.28
const FORGE_ACTIVE_CORE_ALPHA: float = 0.75
const FORGE_ACTIVE_PULSE_SPEED: float = 5.0

const BRAZIER_SCENE = preload(
	"res://RealmView/Brazier.tscn"
)

const CRYSTALLIZED_FLAME_SCENE = preload(
	"res://RealmView/CrystallizedFlame.tscn"
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

	scale = Vector2(
		REALM_VISUAL_SCALE,
		REALM_VISUAL_SCALE
	)

	pivot_offset = size * 0.5
	position = REALM_VISUAL_OFFSET

	_setup_braziers()

	rebuild_realm(state.realm_layout)

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

	if furnace_inner_sprite != null:
		furnace_inner_sprite.visible = false
		furnace_inner_sprite.rotation = 0.0

	if atomic_friction_particles != null:
		atomic_friction_particles.active = false
		atomic_friction_particles.visible = false
		atomic_friction_particles.time = 0.0

	if forge_glow_overlay != null:
		forge_glow_overlay.visible = false

	if forge_spark_overlay != null:
		forge_spark_overlay.visible = false

	if furnace_swirl_overlay != null:
		furnace_swirl_overlay.visible = false
		
	if molecular_agitation_overlay != null:
		molecular_agitation_overlay.active = false
		molecular_agitation_overlay.visible = false
		molecular_agitation_overlay.time = 0.0
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

	generator_textures.clear()

	# ------------------------------------------------------------
	# Build the new realm
	# ------------------------------------------------------------

	_update_island_sprite()

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
	
func _create_crystal() -> void:
	var crystal: CrystallizedFlame = (
		CRYSTALLIZED_FLAME_SCENE.instantiate()
	)

	crystal.scale = Vector2(
		CRYSTAL_BASE_SCALE,
		CRYSTAL_BASE_SCALE
	)

	crystal.position = size * CRYSTAL_CENTER

	add_child(crystal)

	crystal.z_index = 25

	crystallized_flames.append(crystal)


func update_flame_visuals() -> void:
	if state == null:
		return

	var total_flames: float = state.get_resource_amount(
		ResourceIds.CRYSTALIZED_FLAME
	)

	var target_count: int = min(
		int(floor(total_flames)),
		MAX_VISIBLE_CRYSTALS
	)

	while crystallized_flames.size() < target_count:
		_create_crystal()

	while crystallized_flames.size() > target_count:
		_remove_crystal()

	_update_crystal_values(total_flames)
	_position_crystals()


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

	forge_glow_time += _delta
	_update_generator_animations(_delta)
	_update_lava_lakes()
	_update_lava_flow_states()
	_update_furnace_swirl()
	_update_atomic_friction_particles()
	_update_molecular_agitation_overlay()
	_update_atomic_friction_animation(_delta)
	queue_redraw()


func _position_crystals() -> void:
	var count: int = crystallized_flames.size()

	if count == 0:
		return

	var center: Vector2 = size * CRYSTAL_CENTER

	var positions: Array[Vector2] = [
		Vector2(0, -35),

		Vector2(-30, -20),
		Vector2(30, -20),

		Vector2(-60, -5),
		Vector2(60, -5),

		Vector2(-90, 12),
		Vector2(90, 12),

		Vector2(-35, 15),
		Vector2(35, 15),

		Vector2(-120, 32),
		Vector2(120, 32),

		Vector2(-75, 38),
		Vector2(75, 38),

		Vector2(-25, 45),
		Vector2(25, 45),

		Vector2(-145, 58),
		Vector2(145, 58),

		Vector2(-100, 65),
		Vector2(100, 65),

		Vector2(-50, 72),
		Vector2(50, 72),

		Vector2(0, 70),

		Vector2(-170, 85),
		Vector2(170, 85),

		Vector2(-70, 90),
		Vector2(70, 90),

		Vector2(0, 105),

		Vector2(-120, 115),
		Vector2(120, 115),

		Vector2(0, 135)
	]

	var position_count: int = min(
		count,
		positions.size()
	)

	for i in range(position_count):
		var crystal: CrystallizedFlame = (
			crystallized_flames[i]
		)

		var crystal_position: Vector2 = (
			center + positions[i]
		)

		var flame_value: float = 1.0

		if i < crystallized_flame_values.size():
			flame_value = crystallized_flame_values[i]

		var value_scale: float = 1.0 + (
			log(flame_value) * 0.12
		)

		value_scale = clamp(
			value_scale,
			1.0,
			2.5
		)

		crystal.scale = Vector2(
			CRYSTAL_BASE_SCALE,
			CRYSTAL_BASE_SCALE
		) * value_scale

		var rotation_amount: float = 0.0

		if crystal_position.x < center.x:
			rotation_amount = -0.20
		elif crystal_position.x > center.x:
			rotation_amount = 0.20

		crystal.set_base_transform(
			crystal_position,
			rotation_amount
		)


func _remove_crystal() -> void:
	if crystallized_flames.is_empty():
		return

	var crystal: CrystallizedFlame = (
		crystallized_flames.pop_back()
	)

	crystal.queue_free()



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

	_draw_ash(
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
			animated_sprite.z_index = 10
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

			animated_sprite.z_index = 10
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
			_create_molecular_agitation_overlay(
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
				add_child(sprite)
				generator_sprites[generator_id] = sprite

			sprite.z_index = 10
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
	if not realm_layout.generator_layout_positions.has(
		generator_id
	):
		return size * Vector2(
			0.5,
			0.5
		)

	var island_rect: Rect2 = (
		_get_island_rect()
	)

	var normalized_position: Vector2 = (
		realm_layout.generator_layout_positions[
			generator_id
		]
	)

	return (
		island_rect.position +
		island_rect.size *
		normalized_position
	)

func _get_generator_texture(
	generator: Generator
) -> Texture2D:
	var path: String = (
		generator.definition.illustration_path
	)

	if path.is_empty():
		return null

	var generator_id: String = (
		generator.definition.id
	)

	if generator_textures.has(generator_id):
		return generator_textures[generator_id]

	var texture: Texture2D = load(path) as Texture2D

	generator_textures[generator_id] = texture

	return texture


func _draw_ash(
	center: Vector2,
	sx: float,
	ash: float
) -> void:
	if ash <= 0.0:
		return

	var ash_factor: float = min(
		log(ash + 1.0) / 10.0,
		1.0
	)

	var particle_count: int = int(
		8.0 +
		ash_factor * 35.0
	)

	for i in range(particle_count):
		var angle: float = float(i) * 2.71

		var distance: float = (
			sx *
			(
				0.55 +
				fmod(float(i * 13), 100.0) / 180.0
			)
		)

		var position: Vector2 = (
			center +
			Vector2(
				cos(angle) * distance,
				sin(angle) * distance * 0.45 - 35.0
			)
		)

		draw_circle(
			position,
			1.5 + ash_factor * 2.0,
			Color(
				0.40,
				0.40,
				0.42,
				0.15 + ash_factor * 0.35
			)
		)


func _update_layout_drag(
	mouse_position: Vector2
) -> void:
	if dragging_object == "":
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

func _update_crystal_values(
	total_flames: float
) -> void:
	crystallized_flame_values.clear()

	var count: int = crystallized_flames.size()

	if count == 0:
		return

	var remaining: float = max(
		total_flames - float(count),
		0.0
	)

	var total_weight: float = 0.0

	for i in range(count):
		total_weight += float(i + 1)

	for i in range(count):
		var value: float = 1.0

		if remaining > 0.0:
			var weight: float = float(i + 1)

			value += (
				remaining *
				weight /
				total_weight
			)

		crystallized_flame_values.append(value)


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
	var stream := CrystallizationStream.new()

	stream.setup(
		from_position,
		target_position
	)

	stream.z_index = 20

	add_child(stream)

	crystal.scale = Vector2.ZERO

	var target_scale := Vector2(
		CRYSTAL_BASE_SCALE,
		CRYSTAL_BASE_SCALE
	)

	var formation_delay := (
		stream.duration * 0.72
	)

	var tween := create_tween()

	tween.tween_interval(
		formation_delay
	)

	tween.tween_property(
		crystal,
		"scale",
		target_scale * 0.18,
		0.10
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		crystal,
		"scale",
		target_scale * 1.18,
		0.24
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		crystal,
		"scale",
		target_scale,
		0.18
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN_OUT
	)





func _draw_forge_active_glow() -> void:
	if state == null:
		return

	if not state.generators.has("infernal_forge"):
		return

	var forge: Generator = state.generators["infernal_forge"]

	if not forge.unlocked:
		if forge_glow_overlay != null:
			forge_glow_overlay.visible = false

		if forge_spark_overlay != null:
			forge_spark_overlay.visible = false

		return

	if forge_glow_overlay == null:
		forge_glow_overlay = ForgeGlowOverlay.new()
		forge_glow_overlay.name = "ForgeGlowOverlay"
		forge_glow_overlay.z_index = 20
		add_child(forge_glow_overlay)

	if not forge.operating:
		forge_glow_overlay.visible = false

		if forge_spark_overlay != null:
			forge_spark_overlay.visible = false

		return

	forge_glow_overlay.visible = true

	var forge_position: Vector2 = _get_generator_position(
		"infernal_forge"
	)

	var pulse: float = (
		0.5 +
		0.5 * sin(
			forge_glow_time *
			FORGE_ACTIVE_PULSE_SPEED
		)
	)

	var glow_radius: float = (
		FORGE_ACTIVE_GLOW_RADIUS +
		pulse * 5.0
	)

	var glow_alpha: float = (
		FORGE_ACTIVE_GLOW_ALPHA +
		pulse * 0.08
	)

	forge_glow_overlay.position = (
		forge_position +
		Vector2(0, 5)
	)
	forge_glow_overlay.glow_radius = glow_radius
	forge_glow_overlay.glow_alpha = glow_alpha
	forge_glow_overlay.pulse = pulse
	forge_glow_overlay.core_alpha = FORGE_ACTIVE_CORE_ALPHA

	forge_glow_overlay.queue_redraw()
	if forge_spark_overlay == null:
		forge_spark_overlay = ForgeSparkOverlay.new()
		forge_spark_overlay.name = "ForgeSparkOverlay"
		forge_spark_overlay.z_index = 21
		add_child(forge_spark_overlay)

	forge_spark_overlay.position = forge_position + Vector2(0, 5)
	forge_spark_overlay.visible = true

	var sparks: ForgeSparkOverlay = forge_spark_overlay
	sparks.active = true
	sparks.queue_redraw()


# ------------------------------------------------------------
# LAVA NETWORK
# ------------------------------------------------------------



func _create_lava_network() -> void:
	# If setup() is ever called more than once, don't create
	# duplicate lava flows.
	for flow in lava_flows:
		if is_instance_valid(flow):
			flow.queue_free()

	for fall in lava_falls:
		if is_instance_valid(fall):
			fall.queue_free()

	lava_flows.clear()
	lava_falls.clear()

	var island_rect: Rect2 = _get_island_rect()

	for definition in realm_layout.lava_flow_definitions:
		var normalized_points: PackedVector2Array = (
			definition["points"]
		)

		if normalized_points.is_empty():
			continue

		var flow: LavaFlow = (
			LAVA_FLOW_SCENE.instantiate()
		)
		flow.fill_speed_multiplier = randf_range(0.8, 1.25)
		add_child(flow)

		var flow_points: PackedVector2Array = (
			_convert_lava_points(
				normalized_points,
				island_rect
			)
		)

		var flow_widths: PackedFloat32Array = (
			definition["widths"]
		)

		flow.setup(
			flow_points,
			flow_widths,
			definition["speed"],
			definition["thickness"]
		)

		flow.z_index = int(
			definition["flow_z"]
		)

		lava_flows.append(flow)

		# --------------------------------------------------------
		# Fall
		# --------------------------------------------------------

		var fall: LavaFall = (
			LAVA_FALL_SCENE.instantiate()
		)

		add_child(fall)

		var last_normalized_point: Vector2 = (
			normalized_points[
				normalized_points.size() - 1
			]
		)

		fall.position = (
			island_rect.position +
			island_rect.size *
			last_normalized_point
		)

		fall.setup(
			float(definition["fall_width"]),
			float(definition["fall_length"]),
			float(definition["fall_speed"])
		)

		fall.z_index = int(
			definition["fall_z"]
		)

		lava_falls.append(fall)


func _update_lava_network_positions() -> void:
	if lava_flows.is_empty():
		return

	var island_rect: Rect2 = _get_island_rect()

	var flow_definitions: Array[Dictionary] = (
		realm_layout.lava_flow_definitions
	)

	var flow_count: int = min(
		lava_flows.size(),
		flow_definitions.size()
	)

	for i in range(flow_count):
		var flow: LavaFlow = lava_flows[i]

		if not is_instance_valid(flow):
			continue

		var definition: Dictionary = (
			flow_definitions[i]
		)

		var normalized_points: PackedVector2Array = (
			definition["points"]
		)

		var flow_points: PackedVector2Array = (
			_convert_lava_points(
				normalized_points,
				island_rect
			)
		)

		flow.reposition_from_points(
			flow_points
		)

		if i < lava_falls.size():
			var fall: LavaFall = lava_falls[i]

			if is_instance_valid(fall):
				if not normalized_points.is_empty():
					var last_normalized_point: Vector2 = (
						normalized_points[
							normalized_points.size() - 1
						]
					)

					fall.position = (
						island_rect.position +
						island_rect.size *
						last_normalized_point
					)

func _convert_lava_points(
	normalized_points: PackedVector2Array,
	island_rect: Rect2
) -> PackedVector2Array:
	var points := PackedVector2Array()

	for normalized_point in normalized_points:
		points.append(
			island_rect.position +
			island_rect.size *
			normalized_point
		)

	return points

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
	for lake in lava_lakes:
		if is_instance_valid(lake):
			lake.queue_free()

	lava_lakes.clear()

	var island_rect: Rect2 = _get_island_rect()

	# MAIN LAKE
	var main_lake: LavaLake = LAVA_LAKE_SCENE.instantiate()
	add_child(main_lake)
	main_lake.z_index = 6

	main_lake.setup(
		realm_layout.main_lake_edge_points,
		island_rect
	)
	
	
	var overflow: float = (
		state.get_heat_leak_per_second() *
		state.get_overflow_crystallization_multiplier()
	)

	var threshold: float = state.realm_effects.heat_leak_threshold

	main_lake.set_heat(
		overflow,
		threshold
	)
	

	lava_lakes.append(main_lake)

	# SMALLER LAKES
	for definition in realm_layout.small_lake_definitions:
		var lake: LavaLake = LAVA_LAKE_SCENE.instantiate()
		add_child(lake)
		lake.z_index = 6

		lake.setup(
			definition["points"],
			island_rect
		)

		lake.set_fill(0.01)
		lava_lakes.append(lake)

func _update_lava_lakes() -> void:
	if lava_lakes.is_empty():
		return

	var overflow_rate: float = (
		state.get_heat_leak_per_second() *
		state.get_overflow_crystallization_multiplier()
	)

	var main_lake: LavaLake = lava_lakes[0]

	main_lake.set_heat(
		overflow_rate,
		state.realm_effects.heat_leak_threshold
	)

	var main_fill: float = main_lake.fill

	for i in range(realm_layout.small_lake_definitions.size()):
		var lake_index: int = i + 1

		if lake_index >= lava_lakes.size():
			break

		var lake: LavaLake = lava_lakes[lake_index]
		var definition: Dictionary = realm_layout.small_lake_definitions[i]

		var start_fill: float = definition["start_fill"]
		var full_fill: float = definition["full_fill"]

		var small_fill: float = 0.01

		if main_fill > start_fill:
			var fill_range: float = max(
				full_fill - start_fill,
				0.001
			)

			var progress: float = clamp(
				(main_fill - start_fill) / fill_range,
				0.0,
				1.0
			)

			small_fill = lerp(
				0.01,
				1.0,
				progress
			)

		lake.set_fill(small_fill)

func _update_lava_lake_positions() -> void:
	var island_rect: Rect2 = _get_island_rect()

	for lake in lava_lakes:
		if not is_instance_valid(lake):
			continue

		lake.reposition(island_rect)



func _update_lava_flow_states() -> void:
	if state == null:
		return

	if lava_lakes.is_empty():
		return

	var lake: LavaLake = lava_lakes[0]

	if not is_instance_valid(lake):
		return

	var lake_fill: float = lake.fill

	var flow_count: int = min(
		lava_flows.size(),
		realm_layout.lava_flow_definitions.size()
	)

	for i in range(flow_count):
		var flow: LavaFlow = lava_flows[i]

		if not is_instance_valid(flow):
			continue

		var definition: Dictionary = (
			realm_layout.lava_flow_definitions[i]
		)

		var start_fill: float = definition["start_fill"]
		var stop_fill: float = definition["stop_fill"]
		var requires_flow: int = definition.get("requires_flow", -1)

		var dependency_ready: bool = true

		if requires_flow >= 0:
			if requires_flow >= lava_flows.size():
				dependency_ready = false
			else:
				var required_flow: LavaFlow = lava_flows[requires_flow]

				if not is_instance_valid(required_flow):
					dependency_ready = false
				else:
					dependency_ready = (
						required_flow.flow_state ==
						LavaFlow.FlowState.FLOWING
					)

		var should_flow: bool = false

		if flow.flow_state == LavaFlow.FlowState.FLOWING:
			should_flow = lake_fill >= stop_fill
		else:
			should_flow = (
				lake_fill >= start_fill
				and dependency_ready
			)

		flow.set_active(should_flow)

		if i < lava_falls.size():
			var fall: LavaFall = lava_falls[i]

			if is_instance_valid(fall):
				var endpoint_filled: bool = (
					flow.flow_state == LavaFlow.FlowState.FLOWING
				)

				if flow.flow_state == LavaFlow.FlowState.STOPPING:
					endpoint_filled = flow.cooling_length < 1.0

				fall.set_filled(endpoint_filled)	
		
		
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

	if not sprite.visible:
		if furnace_inner_sprite != null:
			furnace_inner_sprite.visible = false
		return

	if furnace.is_operating():
		var level_speed_multiplier: float = (
			1.0 +
			max(furnace.level - 1, 0) * 0.05
		)

		var rotation_speed: float = (
			THERMAL_FURNACE_ROTATION_SPEED *
			level_speed_multiplier
		)

		sprite.rotation += (
			rotation_speed * delta
		)

		if furnace_inner_sprite == null:
			furnace_inner_sprite = Sprite2D.new()
			furnace_inner_sprite.name = "ThermalFurnaceSecondSwirl"
			furnace_inner_sprite.z_index = 11
			add_child(furnace_inner_sprite)

		furnace_inner_sprite.texture = sprite.texture
		furnace_inner_sprite.visible = true
		furnace_inner_sprite.position = sprite.position
		furnace_inner_sprite.scale = sprite.scale
		furnace_inner_sprite.modulate = Color(
			1.0,
			1,
			1,
			.75
		)

		# Same size, opposite direction,
		# slightly faster than the main sprite.
		furnace_inner_sprite.rotation += (
			rotation_speed * 1.2 * delta
		)
	else:
		if furnace_inner_sprite != null:
			furnace_inner_sprite.visible = false
			
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

	if not sprite.visible:
		if furnace_swirl_overlay != null:
			furnace_swirl_overlay.visible = false
		return

	if furnace_swirl_overlay == null:
		furnace_swirl_overlay = FurnaceSwirlOverlay.new()
		furnace_swirl_overlay.name = "FurnaceSwirlOverlay"
		furnace_swirl_overlay.z_index = 11
		add_child(furnace_swirl_overlay)

	furnace_swirl_overlay.position = sprite.position
	furnace_swirl_overlay.visible = furnace.is_operating()

	var swirl: FurnaceSwirlOverlay = furnace_swirl_overlay

	swirl.active = furnace.is_operating()

	swirl.speed_multiplier = (
		1.0 +
		max(furnace.level - 1, 0) * 0.03
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

	if atomic_friction_particles == null:
		atomic_friction_particles = (
			AtomicFrictionParticleOverlay.new()
		)

		atomic_friction_particles.name = (
			"AtomicFrictionParticleOverlay"
		)

		atomic_friction_particles.z_index = 11
		add_child(atomic_friction_particles)

	var particles: AtomicFrictionParticleOverlay = (
		atomic_friction_particles
	)

	particles.position = sprite.position
	particles.visible = (
		sprite.visible and generator.is_operating()
	)

	particles.active = (
		sprite.visible and generator.is_operating()
	)

	particles.generator_level = generator.level



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

	if not sprite.visible or not generator.is_operating():
		return

	var level: int = generator.level

	atomic_friction_time += delta

	var rotation_speed: float = (
		ATOMIC_FRICTION_BASE_ROTATION_SPEED *
		(1.0 + ATOMIC_FRICTION_ROTATION_LEVEL_BONUS * sqrt(float(level)))
	)

	var pulse_speed: float = (
		ATOMIC_FRICTION_BASE_PULSE_SPEED *
		(1.0 + ATOMIC_FRICTION_PULSE_LEVEL_BONUS * sqrt(float(level)))
	)

	sprite.rotation += rotation_speed * delta

	var pulse: float = (
		sin(atomic_friction_time * pulse_speed) + 1.0
	) / 2.0

	var pulse_scale: float = lerp(0.58, .7, pulse)

	var base_scale: Vector2 = sprite.get_meta(
		"atomic_friction_base_scale"
	)

	sprite.scale = base_scale * pulse_scale

func _get_lava_mite_sprite() -> AnimatedSprite2D:
	if generator_sprites.has("lava_mite_colony"):
		return generator_sprites[
			"lava_mite_colony"
		] as AnimatedSprite2D

	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()

	sprite.name = "Generator_lava_mite_colony"

	var sheet: Texture2D = load(
		LAVA_MITE_ANIMATION_PATH
	) as Texture2D

	if sheet == null:
		push_warning(
			"Could not load Lava Mite animation: " +
			LAVA_MITE_ANIMATION_PATH
		)
		return sprite

	var sprite_frames: SpriteFrames = SpriteFrames.new()

	var animation_name: StringName = &"default"

	if not sprite_frames.has_animation(animation_name):
		sprite_frames.add_animation(animation_name)

	sprite_frames.set_animation_speed(
		animation_name,
		LAVA_MITE_ANIMATION_FPS
	)

	sprite_frames.set_animation_loop(
		animation_name,
		true
	)

	var frame_width: int = (
		sheet.get_width() /
		LAVA_MITE_ANIMATION_HFRAMES
	)

	var frame_height: int = (
		sheet.get_height() /
		LAVA_MITE_ANIMATION_VFRAMES
	)

	for row in range(LAVA_MITE_ANIMATION_VFRAMES):
		for column in range(LAVA_MITE_ANIMATION_HFRAMES):
			var atlas_texture: AtlasTexture = AtlasTexture.new()

			atlas_texture.atlas = sheet
			atlas_texture.region = Rect2(
				column * frame_width,
				row * frame_height,
				frame_width,
				frame_height
			)

			sprite_frames.add_frame(
				animation_name,
				atlas_texture
			)

	sprite.sprite_frames = sprite_frames
	sprite.animation = animation_name
	sprite.autoplay = animation_name
	sprite.frame = 0
	sprite.z_index = 10

	add_child(sprite)

	generator_sprites["lava_mite_colony"] = sprite

	return sprite

func _get_matter_furnace_sprite() -> AnimatedSprite2D:
	if generator_sprites.has("matter_furnace"):
		return generator_sprites[
			"matter_furnace"
	] as AnimatedSprite2D

	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()

	sprite.name = "Generator_matter_furnace"

	var sheet: Texture2D = load(
		MATTER_FURNACE_ANIMATION_PATH
	) as Texture2D

	if sheet == null:
		push_warning(
			"Could not load Matter Furnace animation: " +
			MATTER_FURNACE_ANIMATION_PATH
		)
		return sprite

	var sprite_frames: SpriteFrames = SpriteFrames.new()

	var animation_name: StringName = &"default"

	if not sprite_frames.has_animation(animation_name):
		sprite_frames.add_animation(animation_name)

	sprite_frames.set_animation_speed(
		animation_name,
		MATTER_FURNACE_ANIMATION_FPS
	)

	sprite_frames.set_animation_loop(
		animation_name,
		true
	)

	var frame_width: int = (
		sheet.get_width() /
		MATTER_FURNACE_ANIMATION_HFRAMES
	)

	var frame_height: int = (
		sheet.get_height() /
		MATTER_FURNACE_ANIMATION_VFRAMES
	)

	for row in range(MATTER_FURNACE_ANIMATION_VFRAMES):
		for column in range(MATTER_FURNACE_ANIMATION_HFRAMES):
			var atlas_texture: AtlasTexture = (
				AtlasTexture.new()
			)

			atlas_texture.atlas = sheet

			atlas_texture.region = Rect2(
				column * frame_width,
				row * frame_height,
				frame_width,
				frame_height
			)

			sprite_frames.add_frame(
				animation_name,
				atlas_texture
			)

	sprite.sprite_frames = sprite_frames
	sprite.animation = animation_name
	sprite.autoplay = animation_name
	sprite.frame = 0
	sprite.z_index = 10

	add_child(sprite)

	generator_sprites["matter_furnace"] = sprite

	return sprite
	
func _get_lava_mite_size_multiplier(level: int) -> float:
	if level <= 1:
		return 0.70

	if level <= 21:
		var progress: float = (
			float(level - 1) / 20.0
		)

		return lerp(
			0.70,
			1.00,
			progress
		)

	# Diminishing growth after level 21.
	#
	# Level 21 -> 1.00
	# Then approaches 1.25 asymptotically.
	var levels_after_21: float = (
		float(level - 21)
	)

	return 1.0 + (
		0.45 *
		(
			1.0 -
			exp(-levels_after_21 / 30.0)
		)
	)
	
func _update_lava_mite_animation_speed(
	animated_sprite: AnimatedSprite2D,
	level: int
) -> void:
	if animated_sprite.sprite_frames == null:
		return

	var animation_name: StringName = &"default"

	if not animated_sprite.sprite_frames.has_animation(
		animation_name
	):
		return

	var animation_speed: float

	if level <= 1:
		animation_speed = 2.5
	elif level <= 50:
		var progress: float = (
			float(level - 1) / 49.0
		)

		animation_speed = lerp(
			2.5,
			6.5,
			progress
		)
	else:
		# Diminishing speed increase after level 50.
		#
		# Level 50 -> 6.5 FPS
		# Then approaches 8.5 FPS.
		var levels_after_50: float = (
			float(level - 50)
		)

		animation_speed = 6.5 + (
			2.0 *
			(
				1.0 -
				exp(-levels_after_50 / 50.0)
			)
		)

	animated_sprite.sprite_frames.set_animation_speed(
		animation_name,
		animation_speed
	)
	
func _create_molecular_agitation_overlay(
	generator: Generator,
	position: Vector2
	) -> void:

	if molecular_agitation_overlay == null:
		molecular_agitation_overlay = MolecularAgitationParticleOverlay.new()
		molecular_agitation_overlay.name = "MolecularAgitationParticleOverlay"
		molecular_agitation_overlay.z_index = 11

		add_child(molecular_agitation_overlay)

	molecular_agitation_overlay.position = position
	molecular_agitation_overlay.visible = generator.is_operating()
	molecular_agitation_overlay.active = generator.is_operating()
	molecular_agitation_overlay.generator_level = generator.level

func _update_molecular_agitation_overlay() -> void:
	if state == null:
		return

	if not state.generators.has("thermal_furnace"):
		if molecular_agitation_overlay != null:
			molecular_agitation_overlay.visible = false
			molecular_agitation_overlay.active = false
		return

	var generator: Generator = state.generators.get(
		"thermal_furnace"
	)

	if generator == null:
		if molecular_agitation_overlay != null:
			molecular_agitation_overlay.visible = false
			molecular_agitation_overlay.active = false
		return

	if molecular_agitation_overlay == null:
		return

	var should_be_active: bool = (
		generator.unlocked
		and
		generator.level > 0
		and
		generator.is_operating()
	)

	molecular_agitation_overlay.visible = should_be_active
	molecular_agitation_overlay.active = should_be_active
	molecular_agitation_overlay.generator_level = generator.level

	if should_be_active:
		molecular_agitation_overlay.position = _get_generator_position(
			"thermal_furnace"
		)
