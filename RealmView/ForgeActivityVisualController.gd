class_name ForgeActivityVisualController
extends RefCounted


const GLOW_RADIUS: float = 15.0
const GLOW_ALPHA: float = 0.28
const CORE_ALPHA: float = 0.75
const PULSE_SPEED: float = 5.0

var glow_time: float = 0.0
var glow_overlay: ForgeGlowOverlay
var spark_overlay: ForgeSparkOverlay


func advance(delta: float) -> void:
	glow_time += delta


func update(
	parent: Node,
	forge: Generator,
	forge_position: Vector2
) -> void:

	if forge == null or not forge.unlocked or not forge.operating:
		_hide_overlays()
		return

	if glow_overlay == null:
		glow_overlay = ForgeGlowOverlay.new()
		glow_overlay.name = "ForgeGlowOverlay"
		glow_overlay.z_index = 20
		parent.add_child(glow_overlay)

	if spark_overlay == null:
		spark_overlay = ForgeSparkOverlay.new()
		spark_overlay.name = "ForgeSparkOverlay"
		spark_overlay.z_index = 21
		parent.add_child(spark_overlay)

	var pulse: float = 0.5 + 0.5 * sin(glow_time * PULSE_SPEED)

	glow_overlay.position = forge_position + Vector2(0, 5)
	glow_overlay.visible = true
	glow_overlay.glow_radius = GLOW_RADIUS + pulse * 5.0
	glow_overlay.glow_alpha = GLOW_ALPHA + pulse * 0.08
	glow_overlay.pulse = pulse
	glow_overlay.core_alpha = CORE_ALPHA
	glow_overlay.queue_redraw()

	spark_overlay.position = forge_position + Vector2(0, 5)
	spark_overlay.visible = true
	spark_overlay.active = true
	spark_overlay.queue_redraw()


func reset() -> void:
	glow_time = 0.0
	_hide_overlays()


func _hide_overlays() -> void:
	if glow_overlay != null:
		glow_overlay.visible = false

	if spark_overlay != null:
		spark_overlay.visible = false
		spark_overlay.active = false
