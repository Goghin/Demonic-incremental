class_name RealmView
extends Control


var state: GameState
var generator_textures: Dictionary = {}

var braziers: Dictionary = {}
var crystallized_flames: Array[CrystallizedFlame] = []
var crystallized_flame_values: Array[float] = []
var last_crystallized_flame_amount: float = -1.0

const CRYSTAL_BASE_SCALE: float = 0.12
const CRYSTAL_CENTER: Vector2 = Vector2(0.68, 0.3)

const MAX_VISIBLE_CRYSTALS: int = 25


var realm_layout_mode: bool = false
var dragging_object: String = ""
var drag_offset: Vector2 = Vector2.ZERO

var generator_layout_positions: Dictionary = {}
var generator_hitboxes: Dictionary = {}

# Brazier positions are stored as normalized coordinates
# relative to the island rectangle.
var brazier_layout_positions: Dictionary = {
	"stability": Vector2(0.284469, 0.12257),
	"density": Vector2(0.225378, 0.263042),
	"integrity": Vector2(0.831101, 0.231573),
	"intensity": Vector2(0.688068, 0.179388),
	"resonance": Vector2(0.541076, 0.096425)
}

var core_layout_position: Vector2 = Vector2.ZERO
var core_hitbox: Rect2 = Rect2()


const ISLAND_TEXTURE: Texture2D = preload(
	"res://RealmView/infernal_island.png"
)

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
	generator_textures.clear()

	for stat_name in BRAZIER_STATS:
		if braziers.has(stat_name):
			continue

		var brazier_instance: Brazier = (
			BRAZIER_SCENE.instantiate()
			)

		brazier_instance.set_stat(stat_name)

		add_child(brazier_instance)

		brazier_instance.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		braziers[stat_name] = brazier_instance
	
	
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

		var position: Vector2 = center + positions[i]

		var flame_value: float = 1.0

		if i < crystallized_flame_values.size():
			flame_value = crystallized_flame_values[i]

		# ------------------------------------------------------------
		# Crystal size
		#
		# Logarithmic scaling prevents large Flame counts from
		# producing absurdly large crystals.
		# ------------------------------------------------------------

		var value_scale: float = 1.0 + (
			log(flame_value) *
			0.12
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

		if position.x < center.x:
			rotation_amount = -0.20
		elif position.x > center.x:
			rotation_amount = 0.20

		crystal.set_base_transform(
			position,
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

					print("Core -> ", core_layout_position)

					for generator_id in generator_layout_positions:
						print(
							"Generator ",
							generator_id,
							" -> ",
							generator_layout_positions[generator_id]
						)

					for stat_name in BRAZIER_STATS:
						if braziers.has(stat_name):
							print(
								"Brazier ",
								stat_name,
								" -> ",
								brazier_layout_positions[stat_name]
							)

				queue_redraw()
				return

	if not realm_layout_mode:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_layout_drag(
					get_local_mouse_position()
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
	# Core
	# ------------------------------------------------------------

	if (
		core_hitbox.size.x > 0.0
		and
		core_hitbox.size.y > 0.0
	):
		if core_hitbox.has_point(mouse_position):
			dragging_object = "core"

			drag_offset = (
				mouse_position -
				core_hitbox.position
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

			drag_offset = (
				mouse_position -
				hitbox.position
			)

			return


func _draw() -> void:
	if state == null:
		return

	var center: Vector2 = size * Vector2(0.68, 0.66)

	if core_layout_position == Vector2.ZERO:
		core_layout_position = center + Vector2(0, 10)

	var realm: RealmConfiguration = state.realm_configuration
	
	for stat_name in BRAZIER_STATS:
		if not braziers.has(stat_name):
			continue

		var brazier: Brazier = braziers[stat_name]

		brazier.set_stat_value(
			realm.get_stat_value(stat_name)
		)
		
	var density: int = realm.density
	var intensity: int = realm.intensity
	var stability: int = realm.stability
	var integrity: int = realm.integrity
	var resonance: int = realm.resonance

	var ash: float = state.get_resource_amount(
		ResourceIds.ASH
	)

	# Slightly larger realm to give the view more visual presence.
	var realm_scale: float = 1.10

	var density_factor: float = 1.0 + min(
		float(density),
		100.0
	) * 0.003

	var sx: float = 190.0 * realm_scale * density_factor
	var sy: float = 78.0 * realm_scale * density_factor

	# ----------------------------------------------------------------
	# Background
	# ----------------------------------------------------------------

	draw_rect(
		Rect2(Vector2.ZERO, size),
		Color(0.025, 0.014, 0.045)
	)

	# ----------------------------------------------------------------
	# Ambient haze
	# ----------------------------------------------------------------

	draw_circle(
		center + Vector2(0, 25),
		260.0,
		Color(0.12, 0.06, 0.16, 0.10)
	)

	# ----------------------------------------------------------------
	# Distant realm particles
	# Resonance currently only affects ambience.
	# ----------------------------------------------------------------

	var particle_count: int = 35 + resonance * 2

	for i in range(particle_count):
		var angle: float = float(i) * 2.399

		var distance: float = 120.0 + fmod(
			float(i * 73),
			360.0
		)

		var particle_position: Vector2 = center + Vector2(
			cos(angle) * distance,
			sin(angle) * distance * 0.65
		)

		var particle_size: float = 1.0 + fmod(
			float(i),
			2.0
		)

		draw_circle(
			particle_position,
			particle_size,
			Color(0.55, 0.36, 0.65, 0.30)
		)

	# ----------------------------------------------------------------
	# Heat / intensity aura
	# ----------------------------------------------------------------

	var intensity_value: float = min(
		float(intensity),
		100.0
	)

	var glow_radius: float = 125.0 + intensity_value * 1.5
	var glow_alpha: float = 0.10 + intensity_value * 0.002

	draw_circle(
		core_layout_position,
		glow_radius,
		Color(1.0, 0.18, 0.03, glow_alpha)
	)

	# ----------------------------------------------------------------
	# Floating island
	# ----------------------------------------------------------------

	var island_rect: Rect2 = _get_island_rect()

	_initialize_brazier_positions(island_rect)

	draw_texture_rect(
		ISLAND_TEXTURE,
		island_rect,
		false
	)

	# ----------------------------------------------------------------
	# Infernal core
	# ----------------------------------------------------------------

	var core_radius: float = 28.0 + intensity_value * 0.20

	draw_circle(
		core_layout_position,
		core_radius + 20.0,
		Color(1.0, 0.12, 0.02, 0.12)
	)

	draw_circle(
		core_layout_position,
		core_radius,
		Color(0.95, 0.20, 0.035, 0.80)
	)

	draw_circle(
		core_layout_position + Vector2(0, -3),
		core_radius * 0.55,
		Color(1.0, 0.55, 0.10, 0.98)
	)

	if realm_layout_mode:
		core_hitbox = Rect2(
			core_layout_position - Vector2(
				core_radius + 20.0,
				core_radius + 20.0
			),
			Vector2(
				(core_radius + 20.0) * 2.0,
				(core_radius + 20.0) * 2.0
			)
		)

	# ----------------------------------------------------------------
	# Lava channels
	# ----------------------------------------------------------------

	var lava_line_count: int = 3 + min(
		intensity / 15,
		8
	)

	for i in range(lava_line_count):
		var x: float = -sx * 0.72 + (
			float(i) * sx * 1.35 /
			float(max(lava_line_count - 1, 1))
		)

		var lava_alpha: float = 0.65 - min(
			float(stability),
			50.0
		) * 0.006

		draw_line(
			center + Vector2(x, 15),
			center + Vector2(
				x,
				80.0 + fmod(float(i * 19), 45.0)
			),
			Color(1.0, 0.22, 0.035, lava_alpha),
			2.0
		)

	# ----------------------------------------------------------------
	# Generators
	# ----------------------------------------------------------------

	_draw_generators(
		center,
		sx,
		sy
	)

	# ----------------------------------------------------------------
	# Ash
	# ----------------------------------------------------------------

	_draw_ash(
		center,
		sx,
		ash
	)

	# ----------------------------------------------------------------
	# Heat leak
	# ----------------------------------------------------------------

	_draw_heat_leak(
		center,
		sx
	)

	# ----------------------------------------------------------------
	# Layout mode
	# ----------------------------------------------------------------

	if realm_layout_mode:
		_draw_layout_overlay()


func _get_island_rect() -> Rect2:
	var center: Vector2 = size * Vector2(0.68, 0.66)

	var realm: RealmConfiguration = state.realm_configuration

	var density: int = realm.density

	var realm_scale: float = 1.10

	var density_factor: float = 1.0 + min(
		float(density),
		100.0
	) * 0.003

	var sx: float = 190.0 * realm_scale * density_factor
	var sy: float = 78.0 * realm_scale * density_factor

	var island_scale: float = 2.0

	var island_size: Vector2 = Vector2(
		sx * 2.2 * island_scale,
		sy * 2.0 * island_scale
	)

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
			brazier_layout_positions[stat_name]
		)

		var brazier: Control = braziers[stat_name]

		brazier.position = (
			island_rect.position +
			island_rect.size *
			normalized_position
		)


func _draw_layout_overlay() -> void:
	# Border around the RealmView.
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
	# Core selection marker
	# ------------------------------------------------------------

	if core_hitbox.size != Vector2.ZERO:
		draw_rect(
			core_hitbox.grow(3.0),
			Color(1.0, 0.35, 0.05, 0.85),
			false,
			2.0
		)

		draw_line(
			core_layout_position + Vector2(-45, 0),
			core_layout_position + Vector2(45, 0),
			Color(1.0, 0.75, 0.20, 0.5),
			1.0
		)

		draw_line(
			core_layout_position + Vector2(0, -45),
			core_layout_position + Vector2(0, 45),
			Color(1.0, 0.75, 0.20, 0.5),
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


func _island_points(
	center: Vector2,
	sx: float,
	sy: float
	) -> PackedVector2Array:

	var points: PackedVector2Array = PackedVector2Array()

	for i in range(24):
		var angle: float = TAU * float(i) / 24.0

		var wobble: float = 0.88 + (
			fmod(float(i * 17), 100.0) / 500.0
		)

		points.append(
			center + Vector2(
				cos(angle) * sx * wobble,
				sin(angle) * sy * wobble
			)
		)

	return points


func _draw_generators(
	center: Vector2,
	sx: float,
	sy: float
	) -> void:

	# Do not use Array[Generator] here because values()
	# returns an untyped array.
	var active_generators: Array = []

	for generator_value in state.generators.values():
		var generator: Generator = generator_value

		if generator.unlocked and generator.level > 0:
			active_generators.append(generator)

	var count: int = active_generators.size()

	if count == 0:
		generator_hitboxes.clear()
		return

	# Initialize positions only once per generator.
	#
	# Existing generators keep their positions when a new
	# generator is unlocked.
	_initialize_generator_layout_positions(
		center,
		sx,
		sy
	)

	generator_hitboxes.clear()

	for generator in active_generators:
		var generator_id: String = generator.definition.id

		var position: Vector2 = (
			generator_layout_positions[
				generator_id
			]
		)

		# Generator level controls the visual footprint.
		var machine_size: float = 20.0 + (
			min(float(generator.level), 50.0) * 0.25
		)

		var texture: Texture2D = _get_generator_texture(
			generator
		)

		if texture != null:
			var texture_size: Vector2 = texture.get_size()

			var texture_scale: float = min(
				(machine_size * 2.0) /
				max(texture_size.x, 1.0),
				(machine_size * 2.0) /
				max(texture_size.y, 1.0)
			)

			var draw_size: Vector2 = (
				texture_size * texture_scale
			)

			var rect: Rect2 = Rect2(
				position - draw_size * 0.5,
				draw_size
			)

			generator_hitboxes[generator_id] = rect

			# Slightly dim inactive generators rather than
			# replacing their artwork.
			var modulation: Color = Color(
				1.0,
				1.0,
				1.0,
				1.0
			)

			if not generator.is_operating():
				modulation = Color(
					0.70,
					0.70,
					0.70,
					1.0
				)

			draw_texture_rect(
				texture,
				rect,
				false,
				modulation
			)

		else:
			var fallback_color: Color = Color(
				1.0,
				0.32,
				0.08
			)

			if not generator.is_operating():
				fallback_color = Color(
					0.60,
					0.32,
					0.18
				)

			var fallback_rect: Rect2 = Rect2(
				position - Vector2(
					machine_size,
					machine_size
				),
				Vector2(
					machine_size * 2.0,
					machine_size * 2.0
				)
			)

			generator_hitboxes[generator_id] = fallback_rect

			draw_rect(
				fallback_rect,
				fallback_color
			)

		# Keep the visual connection to the movable infernal core.
		draw_line(
			position,
			core_layout_position,
			Color(0.55, 0.25, 0.10, 0.22),
			1.0
		)


func _initialize_generator_layout_positions(
	center: Vector2,
	sx: float,
	sy: float
	) -> void:

	# Use ALL generators when determining default positions.
	#
	# This prevents the old behavior where unlocking a generator
	# changed the number of positions and therefore moved every
	# existing generator.

	var all_generators: Array = []

	for generator_value in state.generators.values():
		var generator: Generator = generator_value
		all_generators.append(generator)

	var total_count: int = all_generators.size()

	if total_count == 0:
		return

	for i in range(total_count):
		var generator: Generator = all_generators[i]
		var generator_id: String = generator.definition.id

		if generator_layout_positions.has(generator_id):
			continue

		var angle: float = (
			-PI * 0.85 +
			PI * 1.7 * float(i) /
			float(max(total_count - 1, 1))
		)

		var position: Vector2 = center + Vector2(
			cos(angle) * sx * 0.62,
			sin(angle) * sy * 0.45 - 8.0
		)

		generator_layout_positions[generator_id] = position


func _get_generator_texture(
	generator: Generator
	) -> Texture2D:

	var path: String = (
		generator.definition.illustration_path
	)

	if path.is_empty():
		return null

	var generator_id: String = generator.definition.id

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
		8.0 + ash_factor * 35.0
	)

	for i in range(particle_count):
		var angle: float = float(i) * 2.71

		var distance: float = sx * (
			0.55 +
			fmod(float(i * 13), 100.0) / 180.0
		)

		var position: Vector2 = center + Vector2(
			cos(angle) * distance,
			sin(angle) * distance * 0.45 - 35.0
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


func _draw_heat_leak(
	center: Vector2,
	sx: float
	) -> void:

	var leak: float = state.get_heat_leak_per_second()

	if leak <= 0.0:
		return

	var threshold: float = (
		state.realm_effects.heat_leak_threshold
	)

	var heat: float = state.get_resource_amount(
		ResourceIds.HEAT
	)

	var excess: float = clamp(
		(heat - threshold) /
		max(threshold, 1.0),
		0.0,
		1.0
	)

	# ------------------------------------------------------------
	# Leak strength
	# ------------------------------------------------------------

	var leak_strength: float = clamp(
		leak /
		max(threshold * 0.25, 1.0),
		0.0,
		1.0
	)

	# ------------------------------------------------------------
	# Heat shimmer
	#
	# Even a small leak should make the realm feel unstable.
	# ------------------------------------------------------------

	var shimmer_count: int = 4 + int(
		leak_strength * 8.0
	)

	for i in range(shimmer_count):
		var angle: float = (
			float(i) * 2.37 +
			Time.get_ticks_msec() * 0.00015
		)

		var distance: float = (
			sx * (
				0.35 +
				fmod(float(i * 17), 100.0) / 180.0
			)
		)

		var position: Vector2 = center + Vector2(
			cos(angle) * distance,
			sin(angle) * distance * 0.30 -
			35.0
		)

		var shimmer_alpha: float = (
			0.05 +
			leak_strength * 0.12
		)

		draw_circle(
			position,
			2.0 + leak_strength * 2.0,
			Color(
				1.0,
				0.30,
				0.06,
				shimmer_alpha
			)
		)

	# ------------------------------------------------------------
	# Heat vents / escape points
	# ------------------------------------------------------------

	var vent_count: int = 3 + int(
		excess * 7.0
	)

	for i in range(vent_count):
		var normalized: float = (
			float(i) /
			float(max(vent_count - 1, 1))
		)

		var x: float = lerp(
			-sx * 0.78,
			sx * 0.78,
			normalized
		)

		# Give each vent a deterministic offset so they don't
		# all line up perfectly.
		var offset: float = (
			fmod(float(i * 37), 31.0) - 15.0
		)

		var vent_position: Vector2 = center + Vector2(
			x,
			12.0 + offset
		)

		# Small glowing source point.
		var vent_radius: float = (
			2.0 +
			leak_strength * 3.0
		)

		draw_circle(
			vent_position,
			vent_radius * 2.5,
			Color(
				1.0,
				0.16,
				0.02,
				0.08 + leak_strength * 0.10
			)
		)

		draw_circle(
			vent_position,
			vent_radius,
			Color(
				1.0,
				0.42,
				0.08,
				0.55 + leak_strength * 0.30
			)
		)

		# --------------------------------------------------------
		# Escaping heat stream
		# --------------------------------------------------------

		var stream_length: float = lerp(
			8.0,
			65.0,
			excess
		)

		var wave: float = sin(
			Time.get_ticks_msec() * 0.004 +
			float(i) * 1.7
		)

		var wave_strength: float = lerp(
			2.0,
			12.0,
			excess
		)

		var end_position: Vector2 = (
			vent_position +
			Vector2(
				wave * wave_strength,
				-stream_length
			)
		)

		# Outer glow.
		draw_line(
			vent_position,
			end_position,
			Color(
				1.0,
				0.18,
				0.025,
				0.08 + leak_strength * 0.12
			),
			5.0 + leak_strength * 4.0
		)

		# Main stream.
		draw_line(
			vent_position,
			end_position,
			Color(
				1.0,
				0.30,
				0.05,
				0.20 + leak_strength * 0.45
			),
			1.5 + leak_strength * 1.5
		)

		# Hot inner core.
		if leak_strength > 0.25:
			draw_line(
				vent_position,
				end_position,
				Color(
					1.0,
					0.72,
					0.20,
					0.25 + leak_strength * 0.45
				),
				0.7 + leak_strength
			)

func _update_layout_drag(mouse_position: Vector2) -> void:
	if dragging_object == "":
		return

	# ------------------------------------------------------------
	# Brazier
	# ------------------------------------------------------------

	if dragging_object.begins_with("brazier:"):
		var stat_name: String = dragging_object.substr(8)

		if braziers.has(stat_name):
			var new_position: Vector2 = (
				mouse_position -
				drag_offset
			)

			var island_rect: Rect2 = _get_island_rect()

			brazier_layout_positions[stat_name] = (
				(new_position - island_rect.position) /
				island_rect.size
			)

			braziers[stat_name].position = new_position

			queue_redraw()

			return

	# ------------------------------------------------------------
	# Core
	# ------------------------------------------------------------

	if dragging_object == "core":
		core_layout_position = (
			mouse_position -
			drag_offset
		)

		queue_redraw()

		return

	# ------------------------------------------------------------
	# Generator
	# ------------------------------------------------------------

	if generator_layout_positions.has(dragging_object):
		generator_layout_positions[
			dragging_object
		] = (
			mouse_position -
			drag_offset
		)

		queue_redraw()


func _update_crystal_values(
	total_flames: float
	) -> void:

	crystallized_flame_values.clear()

	var count: int = crystallized_flames.size()

	if count == 0:
		return

	# ------------------------------------------------------------
	# Up to the visible capacity, every crystal represents at
	# least one actual Crystallized Flame.
	# ------------------------------------------------------------

	var remaining: float = max(
		total_flames - float(count),
		0.0
	)

	# Increasing weights make the larger crystals naturally
	# appear toward the later positions in the formation.
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
