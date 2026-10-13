
class_name RealmLayout
extends Resource


# Background artwork for this realm.
@export var island_texture: Texture2D

# Optional texture aspect ratio. Zero preserves the legacy fixed canvas shape.
@export var island_aspect_ratio: float = 0.0

# Per-layout image/canvas adjustments used by the layout editor.
@export_range(0.5, 2.0, 0.05) var island_view_scale: float = 1.0
@export var island_view_offset: Vector2 = Vector2.ZERO


# Main lava lake outline, using normalized coordinates (0.0 to 1.0).
@export var main_lake_edge_points: PackedVector2Array

# Optional normalized origin for the main lake's expansion. Negative means auto-center.
@export var main_lake_center_position: Vector2 = Vector2(-1.0, -1.0)


# Additional lava reservoirs and their fill settings.
@export var small_lake_definitions: Array[Dictionary] = []


# Lava channels, branches, and waterfall settings.
# Preserve the existing array order because flow dependencies
# refer to other flows by index.
@export var lava_flow_definitions: Array[Dictionary] = []


# Normalized positions of generators on the island texture.
@export var generator_layout_positions: Dictionary = {}


# Normalized positions of realm-stat braziers.
@export var brazier_layout_positions: Dictionary = {}


# Six normalized positions for stored-Ash piles on this layout's artwork.
@export var ash_pile_layout_positions: PackedVector2Array = PackedVector2Array()
