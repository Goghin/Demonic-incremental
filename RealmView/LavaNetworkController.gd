class_name LavaNetworkController
extends RefCounted


func create_network(
	owner: Node,
	realm_layout: RealmLayout,
	island_rect: Rect2,
	lava_flows: Array[LavaFlow],
	lava_falls: Array[LavaFall],
	flow_scene: PackedScene,
	fall_scene: PackedScene
) -> void:
	if realm_layout == null:
		return

	for flow in lava_flows:
		if is_instance_valid(flow):
			flow.queue_free()

	for fall in lava_falls:
		if is_instance_valid(fall):
			fall.queue_free()

	lava_flows.clear()
	lava_falls.clear()

	for definition in realm_layout.lava_flow_definitions:
		var normalized_points: PackedVector2Array = (
			definition["points"]
		)

		if normalized_points.is_empty():
			# Keep array indices aligned with layout definitions because flow
			# dependencies refer to flows by their definition index.
			lava_flows.append(null)
			lava_falls.append(null)
			continue

		var flow: LavaFlow = flow_scene.instantiate()
		flow.fill_speed_multiplier = randf_range(0.8, 1.25)
		owner.add_child(flow)

		var flow_points: PackedVector2Array = _convert_lava_points(
			normalized_points,
			island_rect
		)

		var flow_widths: PackedFloat32Array = (
			definition["widths"]
		)

		flow.setup(
			flow_points,
			flow_widths,
			definition["speed"],
			definition["thickness"]
		)

		flow.z_index = int(definition["flow_z"])
		lava_flows.append(flow)

		if not bool(definition.get("has_fall", true)):
			lava_falls.append(null)
			continue

		var fall: LavaFall = fall_scene.instantiate()
		owner.add_child(fall)

		var last_normalized_point: Vector2 = (
			normalized_points[normalized_points.size() - 1]
		)

		fall.position = (
			island_rect.position +
			island_rect.size * last_normalized_point
		)

		fall.setup(
			float(definition.get("fall_width", 4.0)),
			float(definition.get("fall_length", 60.0)),
			float(definition.get("fall_speed", 100.0))
		)

		fall.z_index = int(definition.get("fall_z", 7))
		lava_falls.append(fall)


func update_positions(
	realm_layout: RealmLayout,
	island_rect: Rect2,
	lava_flows: Array[LavaFlow],
	lava_falls: Array[LavaFall]
) -> void:
	if realm_layout == null:
		return

	if lava_flows.is_empty():
		return

	var flow_definitions: Array[Dictionary] = (
		realm_layout.lava_flow_definitions
	)

	var flow_count: int = min(
		lava_flows.size(),
		flow_definitions.size()
	)

	for i in range(flow_count):
		var flow: LavaFlow = lava_flows[i]

		if not is_instance_valid(flow):
			continue

		var definition: Dictionary = flow_definitions[i]
		var normalized_points: PackedVector2Array = (
			definition["points"]
		)

		var flow_points: PackedVector2Array = _convert_lava_points(
			normalized_points,
			island_rect
		)

		var flow_widths: PackedFloat32Array = definition["widths"]
		flow.reposition_from_points(flow_points, flow_widths)

		if i < lava_falls.size():
			var fall: LavaFall = lava_falls[i]

			if is_instance_valid(fall):
				if not normalized_points.is_empty():
					var last_normalized_point: Vector2 = (
						normalized_points[
							normalized_points.size() - 1
						]
					)

					fall.position = (
						island_rect.position +
						island_rect.size * last_normalized_point
					)

				var fall_width: float = float(definition.get("fall_width", 4.0))
				var fall_length: float = float(definition.get("fall_length", 60.0))
				if not is_equal_approx(fall.width, fall_width) or not is_equal_approx(fall.length, fall_length):
					fall.width = fall_width
					fall.length = fall_length
					fall._update_polygon()


func _convert_lava_points(
	normalized_points: PackedVector2Array,
	island_rect: Rect2
) -> PackedVector2Array:
	var points := PackedVector2Array()

	for normalized_point in normalized_points:
		points.append(
			island_rect.position +
			island_rect.size * normalized_point
		)

	return points
