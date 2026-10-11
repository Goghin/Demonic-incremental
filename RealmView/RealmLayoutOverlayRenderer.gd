class_name RealmLayoutOverlayRenderer
extends Control


var generator_hitboxes: Dictionary = {}
var ash_piles: Array[Sprite2D] = []
var braziers: Dictionary = {}
var brazier_stats: Array[String] = []
var overlay_enabled: bool = false
var draw_controller: RealmLayoutOverlayDrawController = RealmLayoutOverlayDrawController.new()


func setup(view: Control) -> void:
	name = "RealmLayoutOverlayRenderer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.add_child(self)


func update_overlay(
	is_enabled: bool,
	new_generator_hitboxes: Dictionary,
	new_ash_piles: Array[Sprite2D],
	new_braziers: Dictionary,
	new_brazier_stats: Array[String]
) -> void:
	overlay_enabled = is_enabled
	generator_hitboxes = new_generator_hitboxes
	ash_piles = new_ash_piles
	braziers = new_braziers
	brazier_stats = new_brazier_stats
	queue_redraw()


func _draw() -> void:
	if not overlay_enabled:
		return

	draw_controller.draw_overlay(
		self,
		generator_hitboxes,
		ash_piles,
		braziers,
		brazier_stats
	)
