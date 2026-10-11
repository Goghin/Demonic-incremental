class_name RealmLayoutOverlayRenderer
extends Control


var generator_hitboxes: Dictionary = {}
var ash_piles: Array[Sprite2D] = []
var braziers: Dictionary = {}
var brazier_stats: Array[String] = []
var overlay_enabled: bool = false
var selected_object: String = ""
var realm_layout: RealmLayout
var island_rect: Rect2 = Rect2()
var draw_controller: RealmLayoutOverlayDrawController = RealmLayoutOverlayDrawController.new()


func setup(view: Control) -> void:
	name = "RealmLayoutOverlayRenderer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	if get_parent() != view:
		if is_instance_valid(get_parent()):
			reparent(view)
		else:
			view.add_child(self)

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func update_overlay(
	is_enabled: bool,
	new_generator_hitboxes: Dictionary,
	new_ash_piles: Array[Sprite2D],
	new_braziers: Dictionary,
	new_brazier_stats: Array[String],
	new_selected_object: String,
	new_realm_layout: RealmLayout,
	new_island_rect: Rect2
) -> void:
	overlay_enabled = is_enabled
	selected_object = new_selected_object
	realm_layout = new_realm_layout
	island_rect = new_island_rect
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
		brazier_stats,
		selected_object,
		realm_layout,
		island_rect
	)
