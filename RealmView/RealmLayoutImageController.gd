class_name RealmLayoutImageController
extends RefCounted


static var texture_dialog: FileDialog


static func open_texture_dialog(owner: RealmView) -> void:
	if owner.realm_layout == null:
		return

	if texture_dialog == null or not is_instance_valid(texture_dialog):
		texture_dialog = FileDialog.new()
		texture_dialog.name = "RealmLayoutTextureDialog"
		texture_dialog.title = "Choose Realm Island Image"
		texture_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		texture_dialog.access = FileDialog.ACCESS_RESOURCES
		texture_dialog.filters = PackedStringArray([
			"*.png ; PNG Images",
			"*.webp ; WebP Images",
			"*.jpg, *.jpeg ; JPEG Images"
		])
		texture_dialog.file_selected.connect(_on_texture_selected.bind(owner))
		owner.add_child(texture_dialog)
	elif texture_dialog.get_parent() != owner:
		texture_dialog.reparent(owner)

	texture_dialog.popup_centered_ratio(0.75)


static func _on_texture_selected(path: String, owner: RealmView) -> void:
	if not is_instance_valid(owner) or owner.realm_layout == null:
		return

	var loaded_resource: Resource = load(path)
	if not loaded_resource is Texture2D:
		push_warning("Selected file is not a supported texture: " + path)
		return

	var texture := loaded_resource as Texture2D
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		push_warning("Selected texture has invalid dimensions: " + path)
		return

	owner.realm_layout.island_texture = texture
	owner.realm_layout.island_aspect_ratio = texture_size.x / texture_size.y
	owner.realm_layout.island_view_scale = 1.0
	owner.realm_layout.island_view_offset = Vector2.ZERO

	# Reuse the existing layout positioning path so every overlay and generator
	# follows the newly fitted image immediately.
	owner.realm_layout_visual_controller.update_positions(
		owner,
		owner._get_island_rect()
	)
	owner.queue_redraw()
	print("Realm island image set to: ", path, " (", texture_size, ")")
