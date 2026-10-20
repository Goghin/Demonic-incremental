class_name RealmLayoutExportController
extends RefCounted


static var export_dialog: FileDialog


static func open_save_dialog(owner: RealmView) -> void:
	if owner.realm_layout == null:
		return

	if export_dialog == null or not is_instance_valid(export_dialog):
		export_dialog = FileDialog.new()
		export_dialog.name = "RealmLayoutExportDialog"
		export_dialog.title = "Export Realm Layout Source"
		export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		export_dialog.access = FileDialog.ACCESS_FILESYSTEM
		export_dialog.filters = PackedStringArray([
		"*.txt ; GDScript layout source"
	])
		export_dialog.current_file = "NewRealmLayout.txt"
		export_dialog.file_selected.connect(_save_export.bind(owner))
		owner.add_child(export_dialog)
	elif export_dialog.get_parent() != owner:
		export_dialog.reparent(owner)

	export_dialog.current_file = "NewRealmLayout.txt"
	export_dialog.popup_centered_ratio(0.7)


static func _save_export(path: String, owner: RealmView) -> void:
	if owner.realm_layout == null:
		return

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save Realm Layout export: " + path)
		return

	file.store_string(build_script(owner.realm_layout))
	file.close()
	print("Realm layout source exported to: ", path)


static func build_script(layout: RealmLayout) -> String:
	var texture_path: String = ""
	if layout.island_texture != null:
		texture_path = layout.island_texture.resource_path

	var lines: PackedStringArray = PackedStringArray([
		"extends RealmLayout",
		"",
		"",
		"func _init() -> void:",
		"\tisland_texture = preload(" + JSON.stringify(texture_path) + ")",
		"\tisland_aspect_ratio = %.6f" % layout.island_aspect_ratio,
		"\tisland_view_scale = %.6f" % layout.island_view_scale,
		"\tisland_view_offset = " + _serialize_value(layout.island_view_offset, 1),
		"\tmain_lake_edge_points = " + _serialize_value(layout.main_lake_edge_points, 1),
		"\tmain_lake_center_position = " + _serialize_value(layout.main_lake_center_position, 1),
		"\tsmall_lake_definitions = " + _serialize_value(layout.small_lake_definitions, 1),
		"\tlava_flow_definitions = " + _serialize_value(layout.lava_flow_definitions, 1),
		"\tgenerator_layout_positions = " + _serialize_value(layout.generator_layout_positions, 1),
		"\tbrazier_layout_positions = " + _serialize_value(layout.brazier_layout_positions, 1),
		"\tash_pile_layout_positions = " + _serialize_value(layout.ash_pile_layout_positions, 1),
		"\tmatter_pile_layout_positions = " + _serialize_value(layout.matter_pile_layout_positions, 1),
		"\tmatter_pile_layout_rotations = " + _serialize_value(layout.matter_pile_layout_rotations, 1),
		"\tsmoke_emitter_definitions = " + _serialize_value(layout.smoke_emitter_definitions, 1),
		""
	])
	return "\n".join(lines)


static func _serialize_value(value: Variant, indent_level: int = 0) -> String:
	if value is Vector2:
		return "Vector2(%.6f, %.6f)" % [value.x, value.y]

	if value is PackedVector2Array:
		return _serialize_sequence(value, "PackedVector2Array", indent_level)

	if value is PackedFloat32Array:
		return _serialize_sequence(value, "PackedFloat32Array", indent_level)

	if value is PackedInt32Array:
		return _serialize_sequence(value, "PackedInt32Array", indent_level)

	if value is Dictionary:
		if value.is_empty():
			return "{}"
		var parts: PackedStringArray = PackedStringArray()
		for key in value:
			parts.append(
				_indent(indent_level + 1) +
				JSON.stringify(str(key)) +
				": " +
				_serialize_value(value[key], indent_level + 1)
			)
		return "{\n" + ",\n".join(parts) + "\n" + _indent(indent_level) + "}"

	if value is Array:
		return _serialize_sequence(value, "", indent_level)

	if value is String:
		return JSON.stringify(value)

	if value is float:
		return "%.6f" % value

	return str(value)


static func _serialize_sequence(
	values: Variant,
	constructor: String,
	indent_level: int
) -> String:
	if values.is_empty():
		if constructor == "":
			return "[]"
		return constructor + "([])"

	var parts: PackedStringArray = PackedStringArray()
	for value in values:
		parts.append(_indent(indent_level + 1) + _serialize_value(value, indent_level + 1))

	var body := "\n" + ",\n".join(parts) + "\n" + _indent(indent_level)
	if constructor == "":
		return "[" + body + "]"
	return constructor + "([" + body + "])"


static func _indent(level: int) -> String:
	return "\t".repeat(maxi(0, level))
