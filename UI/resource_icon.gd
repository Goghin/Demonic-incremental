class_name ResourceIcon
extends TextureRect


const DEFAULT_ICON_SIZE := Vector2(20.0, 20.0)


func setup(resource_id: String, icon_size: Vector2 = DEFAULT_ICON_SIZE) -> void:
	custom_minimum_size = icon_size
	size = icon_size
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture = ResourceIconRegistry.get_texture(resource_id)

	# A missing icon remains visually unobtrusive and never prevents the UI
	# from displaying the resource name and amount.
	if texture == null:
		modulate = Color(0.55, 0.48, 0.44, 0.8)
