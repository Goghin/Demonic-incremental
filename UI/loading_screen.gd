extends Control


@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var progress_bar: ProgressBar = $CenterContainer/VBoxContainer/ProgressBar





func set_status(text: String) -> void:
	status_label.text = text


func set_progress(value: float) -> void:
	progress_bar.value = value * 100.0


func set_simulation_tick(
	current_tick: int,
	total_ticks: int
	) -> void:
	if total_ticks <= 0:
		return

	var progress = float(current_tick) / float(total_ticks)

	set_progress(progress)

	status_label.text = "Simulating time lost to the void... %d / %d ticks" % [
		current_tick,
		total_ticks
	]
