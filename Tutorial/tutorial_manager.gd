class_name TutorialManager
extends Node

signal tutorial_requested(tutorial_id: String, title: String, message: String)

const SAVE_PATH := "user://tutorial_progress.json"

const TUTORIALS := {
	"first_generator_purchase": {
		"title": "A WORD FROM YOUR INFERNAL INTERN",
		"message": "Excellent! You have made the machinery obey. Generators produce resources over time, and each new level improves their output. Keep an eye on the cost before buying more. I would explain the finer points, but I have a very small attention span."
	}
}

var completed_tutorials: Dictionary = {}
var pending_tutorials: Array[String] = []
var active_tutorial_id: String = ""


func _ready() -> void:
	_load_progress()


func notify_event(event_id: String) -> void:
	var tutorial_id := ""
	match event_id:
		"first_generator_purchase":
			tutorial_id = "first_generator_purchase"
		_:
			return

	if completed_tutorials.get(tutorial_id, false):
		return
	if active_tutorial_id == tutorial_id or pending_tutorials.has(tutorial_id):
		return

	pending_tutorials.append(tutorial_id)
	_show_next_tutorial()


func complete_tutorial(tutorial_id: String) -> void:
	if tutorial_id == "":
		return

	completed_tutorials[tutorial_id] = true
	if active_tutorial_id == tutorial_id:
		active_tutorial_id = ""
	_save_progress()
	_show_next_tutorial()


func _show_next_tutorial() -> void:
	if active_tutorial_id != "" or pending_tutorials.is_empty():
		return

	active_tutorial_id = pending_tutorials.pop_front()
	var tutorial: Dictionary = TUTORIALS.get(active_tutorial_id, {})
	if tutorial.is_empty():
		active_tutorial_id = ""
		_show_next_tutorial()
		return

	tutorial_requested.emit(
		active_tutorial_id,
		str(tutorial.get("title", "INFERNAL INTERN")),
		str(tutorial.get("message", "Something has gone wrong in the tutorial archives."))
	)


func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed := JSON.new()
	var result := parsed.parse(file.get_as_text())
	file.close()
	if result != OK or not parsed.data is Dictionary:
		return

	var saved_completed: Variant = parsed.data.get("completed_tutorials", {})
	if saved_completed is Dictionary:
		completed_tutorials = saved_completed


func _save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save tutorial progress.")
		return

	file.store_string(JSON.stringify({
		"completed_tutorials": completed_tutorials
	}))
	file.close()
