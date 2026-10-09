extends Control


@onready var duration_label: Label = $CenterContainer/PanelContainer/VBoxContainer/DurationLabel
@onready var results_label: Label = $CenterContainer/PanelContainer/VBoxContainer/ResultsLabel
@onready var close_button: Button = $CenterContainer/PanelContainer/VBoxContainer/CloseButton


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)


func show_results(
	offline_seconds: float,
	results_text: String
	) -> void:
	duration_label.text = "You were away for %s." % _format_duration(offline_seconds)

	results_label.text = results_text

	visible = true


func _on_close_pressed() -> void:
	visible = false


func _format_duration(
	seconds: float
	) -> String:
	var total_seconds = int(seconds)

	var hours = total_seconds / 3600
	var minutes = (total_seconds % 3600) / 60
	var remaining_seconds = total_seconds % 60

	if hours > 0:
		return "%dh %02dm" % [
			hours,
			minutes
		]

	if minutes > 0:
		return "%dm %02ds" % [
			minutes,
			remaining_seconds
		]

	return "%ds" % remaining_seconds
