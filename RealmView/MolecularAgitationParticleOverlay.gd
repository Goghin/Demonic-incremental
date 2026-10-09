class_name MolecularAgitationParticleOverlay
extends Node2D


# ============================================================
# TUNING
# ============================================================

# Particle count
const BASE_PARTICLES: int = 7

# Adds one particle every N levels.
const PARTICLES_PER_LEVELS: int = 3

# Safety limit for the particle count.
const MAX_PARTICLES: int = 50


# Overall size of the electron cloud
const MIN_ORBIT_RADIUS: float = 10.0
const MAX_ORBIT_RADIUS: float = 22.0

# How stretched the orbit is vertically.
# 1.0 = circular
# 0.5 = very flat
const MIN_ELLIPSE: float = 0.65
const MAX_ELLIPSE: float = 0.95


# Orbit speed
const MIN_ORBIT_SPEED: float = 0.80
const MAX_ORBIT_SPEED: float = 2.42

# How much generator level increases activity.
# Higher = more speed increase per level.
const LEVEL_ACTIVITY: float = 0.035


# Particle size
const MIN_PARTICLE_SIZE: float = 0.9
const MAX_PARTICLE_SIZE: float = 1.7

# Size of the faint outer glow relative to the particle
const GLOW_SIZE_MULTIPLIER: float = 2.5


# Pulsing
const MIN_PULSE_SPEED: float = 0.9
const MAX_PULSE_SPEED: float = 1.95

# How strongly particles pulse.
# 0.0 = no pulsing
# 0.18 = current amount
# 0.5 = very noticeable
const PULSE_AMOUNT: float = 0.18

# Base particle size while pulsing
const PULSE_BASE: float = 0.82


# ============================================================
# CENTRAL CORE
# ============================================================

# Main size of the central energy point
const CORE_SIZE: float = 3.5

# Size of the soft outer glow
const CORE_GLOW_SIZE: float = 12.0

# How strongly the core pulses
const CORE_PULSE_AMOUNT: float = 0.19

# Speed of the core pulse
const CORE_PULSE_SPEED: float = 0.8

# Alpha of the outer glow
const CORE_GLOW_ALPHA: float = 0.12

# Alpha of the main core
const CORE_ALPHA: float = 0.85


# ============================================================
# STATE
# ============================================================

var time: float = 0.0
var active: bool = false
var generator_level: int = 1

var particle_radii: Array[float] = []
var particle_angles: Array[float] = []
var particle_speeds: Array[float] = []
var particle_pulse_speeds: Array[float] = []
var particle_pulse_phases: Array[float] = []
var particle_sizes: Array[float] = []
var particle_ellipse: Array[float] = []


func _ready() -> void:
	_initialize_particles()


func _process(delta: float) -> void:
	if not active:
		return

	time += delta
	queue_redraw()


func _initialize_particles() -> void:
	particle_radii.clear()
	particle_angles.clear()
	particle_speeds.clear()
	particle_pulse_speeds.clear()
	particle_pulse_phases.clear()
	particle_sizes.clear()
	particle_ellipse.clear()

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 483927

	for i in range(MAX_PARTICLES):
		var radius: float = rng.randf_range(
			MIN_ORBIT_RADIUS,
			MAX_ORBIT_RADIUS
		)

		var angle: float = rng.randf_range(
			0.0,
			TAU
		)

		var speed: float = rng.randf_range(
			MIN_ORBIT_SPEED,
			MAX_ORBIT_SPEED
		)

		var pulse_speed: float = rng.randf_range(
			MIN_PULSE_SPEED,
			MAX_PULSE_SPEED
		)

		var pulse_phase: float = rng.randf_range(
			0.0,
			TAU
		)

		var size: float = rng.randf_range(
			MIN_PARTICLE_SIZE,
			MAX_PARTICLE_SIZE
		)

		var ellipse: float = rng.randf_range(
			MIN_ELLIPSE,
			MAX_ELLIPSE
		)

		particle_radii.append(radius)
		particle_angles.append(angle)
		particle_speeds.append(speed)
		particle_pulse_speeds.append(pulse_speed)
		particle_pulse_phases.append(pulse_phase)
		particle_sizes.append(size)
		particle_ellipse.append(ellipse)


func _get_particle_count() -> int:
	var level: int = max(generator_level, 1)

	var additional_particles: int = (
		(level - 1)
		/ PARTICLES_PER_LEVELS
	)

	var count: int = (
		BASE_PARTICLES
		+ additional_particles
	)

	return min(count, MAX_PARTICLES)


func _get_activity_multiplier() -> float:
	var level: float = float(max(generator_level, 1))

	return 1.0 + LEVEL_ACTIVITY * sqrt(level - 1.0)


func _draw() -> void:
	if not active:
		return

	var particle_count: int = _get_particle_count()
	var activity: float = _get_activity_multiplier()

	# --------------------------------------------------------
	# PARTICLES
	# --------------------------------------------------------

	for i in range(particle_count):
		var orbit_angle: float = (
			particle_angles[i]
			+ time * particle_speeds[i] * activity
		)

		var pulse: float = (
			PULSE_BASE
			+ PULSE_AMOUNT
			* sin(
				time * particle_pulse_speeds[i]
				+ particle_pulse_phases[i]
			)
		)

		var radius: float = (
			particle_radii[i]
			* pulse
		)

		var particle_position: Vector2 = Vector2(
			cos(orbit_angle) * radius,
			sin(orbit_angle)
			* radius
			* particle_ellipse[i]
		)

		var particle_size: float = (
			particle_sizes[i]
			* pulse
		)

		var glow_size: float = (
			particle_size
			* GLOW_SIZE_MULTIPLIER
		)

		# Soft purple particle glow
		draw_circle(
			particle_position,
			glow_size,
			Color(
				0.55,
				0.20,
				0.95,
				0.10
			)
		)

		# Main particle
		draw_circle(
			particle_position,
			particle_size,
			Color(
				0.72,
				0.38,
				1.0,
				0.75
			)
		)

		# Bright particle center
		draw_circle(
			particle_position,
			particle_size * 0.45,
			Color(
				0.92,
				0.78,
				1.0,
				0.95
			)
		)


	# --------------------------------------------------------
	# CENTRAL ENERGY CORE
	# --------------------------------------------------------

	var core_pulse: float = (
		1.0
		+ CORE_PULSE_AMOUNT
		* sin(time * CORE_PULSE_SPEED)
	)

	var core_size: float = (
		CORE_SIZE
		* core_pulse
	)

	var core_glow_size: float = (
		CORE_GLOW_SIZE
		* core_pulse
	)


	# Large, faint outer glow
	draw_circle(
		Vector2.ZERO,
		core_glow_size,
		Color(
			0.45,
			0.10,
			0.85,
			CORE_GLOW_ALPHA
		)
	)

	# Smaller concentrated glow
	draw_circle(
		Vector2.ZERO,
		core_glow_size * 0.55,
		Color(
			0.65,
			0.20,
			1.0,
			0.18
		)
	)

	# Main energy core
	draw_circle(
		Vector2.ZERO,
		core_size,
		Color(
			0.72,
			0.32,
			1.0,
			CORE_ALPHA
		)
	)

	# Very bright center
	draw_circle(
		Vector2.ZERO,
		core_size * 0.45,
		Color(
			0.95,
			0.85,
			1.0,
			1.0
		)
	)
