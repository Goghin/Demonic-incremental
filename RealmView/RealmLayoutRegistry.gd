class_name RealmLayoutRegistry
extends RefCounted


const LAYOUTS: Dictionary = {
	"default":
		preload("res://RealmView/Layouts/DefaultRealmLayout.gd"),

	"test":
		preload("res://RealmView/Layouts/TestRealmLayout.gd"),

	#"ashen_wastes":
		#preload("res://RealmView/Layouts/AshenWastesRealmLayout.gd"),

	#"blood_crater":
		#preload("res://RealmView/Layouts/BloodCraterRealmLayout.gd"),
}


static func create_layout(
	layout_id: String
	) -> RealmLayout:

	if not LAYOUTS.has(layout_id):
		push_warning(
			"Unknown realm layout: " + layout_id
		)

		layout_id = "default"

	return LAYOUTS[layout_id].new()
