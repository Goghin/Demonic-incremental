extends Control


@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var progress_bar: ProgressBar = $CenterContainer/VBoxContainer/ProgressBar

signal debug_step_multiplier_changed(multiplier: float)

var debug_step_toggle: CheckBox
var debug_step_selector: OptionButton


func _ready() -> void:
	# Temporary diagnostic controls; never persist to the save file.
	var container: VBoxContainer = $CenterContainer/VBoxContainer
	debug_step_toggle = CheckBox.new()
	debug_step_toggle.text = "Fast offline simulation (testing only; inaccurate)"
	debug_step_toggle.button_pressed = false
	container.add_child(debug_step_toggle)
	debug_step_selector = OptionButton.new()
	debug_step_selector.add_item("10x step size", 0)
	debug_step_selector.add_item("50x step size", 1)
	debug_step_selector.select(0)
	debug_step_selector.visible = false
	container.add_child(debug_step_selector)
	debug_step_toggle.toggled.connect(_on_debug_step_changed)
	debug_step_selector.item_selected.connect(_on_debug_step_option_changed)


func set_debug_step_controls_visible(enabled: bool) -> void:
	debug_step_toggle.visible = enabled
	debug_step_selector.visible = enabled and debug_step_toggle.button_pressed


func _on_debug_step_changed(enabled: bool) -> void:
	debug_step_selector.visible = enabled
	_emit_debug_step_multiplier()


func _on_debug_step_option_changed(_index: int) -> void:
	_emit_debug_step_multiplier()


func _emit_debug_step_multiplier() -> void:
	var multiplier: float = 1.0
	if debug_step_toggle.button_pressed:
		multiplier = 50.0 if debug_step_selector.selected == 1 else 10.0
	debug_step_multiplier_changed.emit(multiplier)





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
