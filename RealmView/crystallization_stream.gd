class_name CrystallizationStream
extends Node2D


var start_position: Vector2
var target_position: Vector2

var duration: float = 1.35

var elapsed: float = 0.0
var active: bool = true

var particle_count: int = 28
var particles: Array = []

var curve_strength: float = 18.0
var pulse_phase: float = 0.0
var burst_mode: bool = false


func setup(
	from: Vector2,
	to: Vector2
	) -> void:

	burst_mode = false
	start_position = from
	target_position = to

	elapsed = 0.0
	active = true

	particles.clear()

	var direction := target_position - start_position
	var length := direction.length()

	if length > 0.0:
		curve_strength = clamp(
			length * 0.08,
			12.0,
			35.0
		)

	for i in range(particle_count):
		particles.append({
			"offset": randf(),
			"side": randf_range(-1.0, 1.0),
			"size": randf_range(1.5, 4.0),
			"speed": randf_range(0.8, 1.25),
			"phase": randf_range(0.0, TAU),
			"angle": randf_range(0.0, TAU),
			"burst_speed": randf_range(55.0, 145.0)
		})

	queue_redraw()


func setup_burst(at_position: Vector2) -> void:
	burst_mode = true
	start_position = at_position
	target_position = at_position
	elapsed = 0.0
	duration = 0.7
	active = true
	particles.clear()

	for i in range(42):
		particles.append({
			"angle": randf_range(0.0, TAU),
			"burst_speed": randf_range(65.0, 175.0),
			"size": randf_range(1.2, 3.8),
			"phase": randf_range(0.0, TAU)
		})

	queue_redraw()


func _process(delta: float) -> void:

	if not active:
		return

	elapsed += delta
	pulse_phase += delta * 8.0

	if elapsed >= duration:
		elapsed = duration
		active = false

	queue_redraw()

	if not active:
		queue_free()


func _get_stream_position(progress: float) -> Vector2:

	progress = clamp(
		progress,
		0.0,
		1.0
	)

	var position := start_position.lerp(
		target_position,
		progress
	)

	var direction := target_position - start_position

	if direction.length_squared() <= 0.001:
		return position

	var perpendicular := Vector2(
		-direction.y,
		direction.x
	).normalized()

	var curve := sin(
		progress * PI
	)

	position += perpendicular * (
		curve *
		curve_strength
	)

	return position


func _draw() -> void:

	if not active:
		return

	if burst_mode:
		_draw_burst()
		return

	var progress := elapsed / duration

	# --------------------------------------------------------
	# Main energy stream
	# --------------------------------------------------------

	var stream_points: PackedVector2Array = []

	var point_count := 20

	for i in range(point_count):
		var t := float(i) / float(point_count - 1)

		# The visible stream has a slight travelling pulse.
		var local_t: float = clampf(
			progress - 0.15 + t * 0.15,
			0.0,
			1.0
		)

		var point := _get_stream_position(local_t)

		stream_points.append(point)

	if stream_points.size() >= 2:

		# Dark outer energy body.
		draw_polyline(
			stream_points,
			Color(
				0.45,
				0.08,
				0.01,
				0.45
			),
			9.0,
			true
		)

		# Hot orange core.
		draw_polyline(
			stream_points,
			Color(
				1.0,
				0.28,
				0.02,
				0.85
			),
			5.0,
			true
		)

		# White-hot center.
		draw_polyline(
			stream_points,
			Color(
				1.0,
				0.82,
				0.35,
				0.95
			),
			2.0,
			true
		)

		# --------------------------------------------------------
	# Travelling particles
	# --------------------------------------------------------

	for particle in particles:

		var particle_progress: float = (
			float(particle["offset"]) +
			progress *
			float(particle["speed"])
		)

		particle_progress = fmod(
			particle_progress,
			1.0
		)

		var particle_position: Vector2 = _get_stream_position(
			particle_progress
		)

		var direction: Vector2 = (
			target_position -
			start_position
		)

		if direction.length_squared() > 0.001:

			var perpendicular: Vector2 = Vector2(
				-direction.y,
				direction.x
			).normalized()

			var wave: float = sin(
				particle_progress * 18.0 +
				float(particle["phase"]) +
				pulse_phase
			)

			particle_position += perpendicular * (
				wave *
				float(particle["side"]) *
				5.0
			)

		var fade: float = 1.0

		if particle_progress < 0.08:
			fade = particle_progress / 0.08
		elif particle_progress > 0.88:
			fade = (
				1.0 -
				particle_progress
			) / 0.12

		var size: float = (
			float(particle["size"]) *
			fade
		)

		if size > 0.0:

			draw_circle(
				particle_position,
				size * 1.8,
				Color(
					1.0,
					0.20,
					0.01,
					0.18 * fade
				)
			)

			draw_circle(
				particle_position,
				size,
				Color(
					1.0,
					0.65,
					0.12,
					0.9 * fade
				)
			)

			draw_circle(
				particle_position,
				size * 0.45,
				Color(
					1.0,
					0.95,
					0.65,
					fade
				)
			)

	# --------------------------------------------------------
	# Forge-side energy buildup
	# --------------------------------------------------------

	var start_pulse := (
		1.0 +
		sin(pulse_phase) * 0.18
	)

	draw_circle(
		start_position,
		11.0 * start_pulse,
		Color(
			1.0,
			0.20,
			0.01,
			0.16
		)
	)

	draw_circle(
		start_position,
		6.0 * start_pulse,
		Color(
			1.0,
			0.65,
			0.12,
			0.75
		)
	)

	draw_circle(
		start_position,
		2.5 * start_pulse,
		Color(
			1.0,
			0.95,
			0.75,
			1.0
		)
	)

	# --------------------------------------------------------
	# Formation flash at destination
	# --------------------------------------------------------

	if progress > 0.82:

		var formation_progress := (
			progress - 0.82
		) / 0.18

		var flash := 1.0 - formation_progress

		draw_circle(
			target_position,
			24.0 * flash,
			Color(
				1.0,
				0.25,
				0.01,
				0.10 * flash
			)
		)

		draw_circle(
			target_position,
			10.0 * flash,
			Color(
				1.0,
				0.72,
				0.18,
				0.45 * flash
			)
		)



func _draw_burst() -> void:
	var progress: float = clampf(elapsed / duration, 0.0, 1.0)
	var fade: float = 1.0 - progress
	var pulse: float = 1.0 + sin(progress * PI) * 0.45

	for particle in particles:
		var angle: float = float(particle["angle"])
		var direction := Vector2(cos(angle), sin(angle))
		var distance: float = float(particle["burst_speed"]) * elapsed
		var wobble: float = sin(elapsed * 24.0 + float(particle["phase"])) * 3.0
		var position: Vector2 = start_position + direction * distance
		position += direction.rotated(PI * 0.5) * wobble
		var size: float = float(particle["size"]) * fade

		if size <= 0.0:
			continue

		draw_line(
			position - direction * size * 2.4,
			position,
			Color(1.0, 0.28, 0.02, 0.65 * fade),
			maxf(size * 1.2, 0.7),
			true
		)
		draw_circle(position, size * 1.7, Color(1.0, 0.25, 0.01, 0.18 * fade))
		draw_circle(position, size, Color(1.0, 0.68, 0.12, 0.9 * fade))
		draw_circle(position, size * 0.42, Color(1.0, 0.96, 0.72, fade))

	draw_circle(start_position, 12.0 * pulse * fade, Color(1.0, 0.28, 0.02, 0.2 * fade))
	draw_circle(start_position, 5.0 * pulse * fade, Color(1.0, 0.72, 0.18, 0.8 * fade))
