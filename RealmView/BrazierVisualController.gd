class_name BrazierVisualController
extends RefCounted


func setup(
	owner: Control,
	braziers: Dictionary,
	brazier_stats: Array[String],
	brazier_scene: PackedScene
) -> void:
	for stat_name in brazier_stats:
		if braziers.has(stat_name):
			continue

		var brazier_instance: Brazier = (
			brazier_scene.instantiate()
		)

		brazier_instance.set_stat(stat_name)

		owner.add_child(brazier_instance)

		brazier_instance.z_index = 15

		brazier_instance.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		braziers[stat_name] = brazier_instance


func position_braziers(
	braziers: Dictionary,
	brazier_stats: Array[String],
	realm_layout: RealmLayout,
	island_rect: Rect2
) -> void:
	for stat_name in brazier_stats:
		if not braziers.has(stat_name):
			continue

		var normalized_position: Vector2 = (
			realm_layout.brazier_layout_positions[
				stat_name
			]
		)

		var brazier: Control = braziers[stat_name]

		brazier.position = (
			island_rect.position +
			island_rect.size *
			normalized_position
		)
