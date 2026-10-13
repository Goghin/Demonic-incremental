class_name RealmLayoutRegistry
extends RefCounted


const LAYOUTS: Dictionary = {
	"default":
		preload("res://RealmView/Layouts/DefaultRealmLayout.gd"),
#
	

	"island_1":
		preload("res://RealmView/Layouts/BasicRealms/Realm1Layout.gd"),

	"island_2":
		preload("res://RealmView/Layouts/BasicRealms/Realm2Layout.gd"),


	"island_3":
		preload("res://RealmView/Layouts/BasicRealms/Realm4Layout.gd"),

	"rune_1":
		preload("res://RealmView/Layouts/BasicRealms/Rune1RealmLayout.gd"),
		
	"is1":
		preload("res://RealmView/Layouts/BasicRealms/Island1RealmLayout.gd"),

	"is2":
		preload("res://RealmView/Layouts/BasicRealms/Island2RealmLayout.gd"),
	"is3":
		preload("res://RealmView/Layouts/BasicRealms/Island3RealmLayout.gd"),
}


static func get_layout_ids() -> Array[String]:
	# Keep experimental layouts out of the normal cycling order.
	return [ "island_1", "island_2", "is1", "is2","is3", "island_3","rune_1" ]  
	


static func create_layout(
	layout_id: String
	) -> RealmLayout:

	if not LAYOUTS.has(layout_id):
		push_warning(
			"Unknown realm layout: " + layout_id
		)

		layout_id = "default"

	var layout: RealmLayout = LAYOUTS[layout_id].new()
	layout.resource_name = layout_id
	return layout
