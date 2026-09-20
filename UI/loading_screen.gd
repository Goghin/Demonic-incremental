
extends Control


@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var progress_bar: ProgressBar = $CenterContainer/VBoxContainer/ProgressBar


func set_status(text: String) -> void:
	status_label.text = text


func set_progress(value: float) -> void:
	progress_bar.value = value * 100.0
