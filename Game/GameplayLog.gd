class_name GameplayLog
extends RefCounted


const LOG_PATH: String = "user://gameplay_log.jsonl"
const MAX_MEMORY_EVENTS: int = 2000
const MAX_LOG_BYTES: int = 2 * 1024 * 1024


var enabled: bool = true
var events: Array[Dictionary] = []
var _file_warning_reported: bool = false


func record_event(
	category: String,
	event_name: String,
	details: Dictionary = {},
	source: String = "game"
) -> void:
	if not enabled:
		return

	var entry: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(),
		"unix_time": int(Time.get_unix_time_from_system()),
		"category": category,
		"event": event_name,
		"source": source,
		"details": details.duplicate(true)
	}

	events.append(entry)
	while events.size() > MAX_MEMORY_EVENTS:
		events.pop_front()

	_append_to_file(entry)


func get_recent_events(limit: int = 100) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var start_index: int = maxi(0, events.size() - maxi(0, limit))
	for index in range(start_index, events.size()):
		result.append(events[index].duplicate(true))
	return result


func clear_memory_events() -> void:
	events.clear()


func _append_to_file(entry: Dictionary) -> void:
	var line: String = JSON.stringify(entry)
	var file: FileAccess

	if FileAccess.file_exists(LOG_PATH):
		file = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	else:
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE)

	if file == null:
		_warn_file_unavailable()
		return

	var line_size: int = line.to_utf8_buffer().size() + 1
	if file.get_length() + line_size > MAX_LOG_BYTES:
		file.close()
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
		if file == null:
			_warn_file_unavailable()
			return

	file.seek_end()
	file.store_line(line)
	file.close()


func _warn_file_unavailable() -> void:
	if _file_warning_reported:
		return

	_file_warning_reported = true
	push_warning("GameplayLog could not write to " + LOG_PATH)
