class_name RealmView
extends Control

var state: GameState

func setup(game_state: GameState) -> void:
	state = game_state
	queue_redraw()

func _process(_delta: float) -> void:
	if state != null:
		queue_redraw()

func _draw() -> void:
	if state == null:
		return

	var center := size * Vector2(0.68, 0.55)
	var realm := state.realm_configuration
	var density := realm.density
	var intensity := realm.intensity
	var stability := realm.stability
	var integrity := realm.integrity
	var resonance := realm.resonance
	var ash := state.get_resource_amount(ResourceIds.ASH)

	var sx := 190.0 * (1.0 + min(density, 100) * 0.003)
	var sy := 78.0 * (1.0 + min(density, 100) * 0.003)

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.008, 0.025))

	# Distant realm particles. Resonance currently only affects ambience.
	for i in range(35 + resonance * 2):
		var a := float(i) * 2.399
		var d := 120.0 + fmod(float(i * 73), 360.0)
		draw_circle(
			center + Vector2(cos(a) * d, sin(a) * d * 0.65),
			1.0 + fmod(float(i), 2.0),
			Color(0.45, 0.28, 0.55, 0.25)
		)

	# Heat / intensity aura.
	var glow := 115.0 + min(intensity, 100) * 1.5
	draw_circle(center + Vector2(0, 12), glow, Color(1.0, 0.18, 0.03, 0.08 + min(intensity, 100) * 0.002))

	var points := _island_points(center, sx, sy)
	draw_colored_polygon(points, Color(0.075, 0.065, 0.085))
	draw_polyline(points, Color(0.30, 0.22, 0.32, 0.8), 1.0 + min(integrity, 50) * 0.025, true)

	# Floating rock underside.
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-sx * 0.72, 28),
		center + Vector2(-sx * 0.45, 105 + density),
		center + Vector2(-sx * 0.15, 145 + density * 0.5),
		center + Vector2(0, 92 + density),
		center + Vector2(sx * 0.40, 70 + density * 0.5),
		center + Vector2(sx * 0.70, 25)
	]), Color(0.045, 0.038, 0.052))

	# Infernal core.
	var core := 25.0 + min(intensity, 100) * 0.18
	draw_circle(center + Vector2(0, 10), core + 18.0, Color(1.0, 0.12, 0.02, 0.10))
	draw_circle(center + Vector2(0, 10), core, Color(0.95, 0.20, 0.035, 0.75))
	draw_circle(center + Vector2(0, 7), core * 0.55, Color(1.0, 0.55, 0.10, 0.95))

	# Lava channels.
	var lines := 3 + min(intensity / 15, 8)
	for i in range(lines):
		var x := -sx * 0.72 + float(i) * sx * 1.35 / max(lines - 1, 1)
		draw_line(
			center + Vector2(x, 15),
			center + Vector2(x, 80 + fmod(float(i * 19), 45.0)),
			Color(1.0, 0.22, 0.035, 0.65 - min(stability, 50) * 0.006),
			2.0
		)

	_draw_generators(center, sx, sy)
	_draw_ash(center, sx, ash)
	_draw_heat_leak(center, sx)

func _island_points(center: Vector2, sx: float, sy: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(24):
		var a := TAU * float(i) / 24.0
		var wobble := 0.88 + fmod(float(i * 17), 100.0) / 500.0
		points.append(center + Vector2(cos(a) * sx * wobble, sin(a) * sy * wobble))
	return points

func _draw_generators(center: Vector2, sx: float, sy: float) -> void:
	var active_generators: Array[Generator] = []
	for generator in state.generators.values():
		if generator.unlocked and generator.level > 0:
			active_generators.append(generator)

	var count := active_generators.size()
	if count == 0:
		return

	for i in range(count):
		var generator := active_generators[i]
		var a := -PI * 0.85 + PI * 1.7 * float(i) / max(count - 1, 1)
		var position := center + Vector2(cos(a) * sx * 0.62, sin(a) * sy * 0.45 - 8)
		var s := 5.0 + min(generator.level, 50) * 0.10
		var c := Color(1.0, 0.32, 0.08) if generator.is_operating() else Color(0.60, 0.32, 0.18)

		draw_rect(Rect2(position - Vector2(s, s), Vector2(s * 2.0, s * 2.0)), c)
		draw_line(position, center + Vector2(0, 10), Color(0.50, 0.20, 0.08, 0.18), 1.0)

func _draw_ash(center: Vector2, sx: float, ash: float) -> void:
	if ash <= 0.0:
		return

	var factor := min(log(ash + 1.0) / 10.0, 1.0)
	for i in range(int(8 + factor * 35.0)):
		var a := float(i) * 2.71
		var d := sx * (0.55 + fmod(float(i * 13), 100.0) / 180.0)
		draw_circle(
			center + Vector2(cos(a) * d, sin(a) * d * 0.45 - 35),
			1.5 + factor * 2.0,
			Color(0.35, 0.35, 0.36, 0.15 + factor * 0.35)
		)

func _draw_heat_leak(center: Vector2, sx: float) -> void:
	if state.get_heat_leak_per_second() <= 0.0:
		return

	var threshold := state.realm_effects.heat_leak_threshold
	var excess := clamp(
		(state.get_resource_amount(ResourceIds.HEAT) - threshold) / max(threshold, 1.0),
		0.0,
		1.0
	)
	var count := 3 + int(excess * 10.0)

	for i in range(count):
		var x := -sx * 0.8 + float(i) * sx * 1.6 / max(count - 1, 1)
		draw_line(
			center + Vector2(x, 18),
			center + Vector2(x + sin(float(i)) * 10.0, -45.0 - excess * 35.0),
			Color(1.0, 0.28, 0.05, 0.35),
			1.5
		)
