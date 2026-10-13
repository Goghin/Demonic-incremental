extends PanelContainer


@onready var heading_label: Label = $Content/HeadingLabel
@onready var title_label: Label = $Content/TitleLabel
@onready var description_label: Label = $Content/DescriptionLabel


var active_tween: Tween


func show_achievement(
	achievement_title: String,
	achievement_description: String
	) -> void:

	if active_tween != null and active_tween.is_valid():
		active_tween.kill()

	heading_label.text = "ACHIEVEMENT UNLOCKED"
	title_label.text = achievement_title
	description_label.text = achievement_description

	visible = true
	modulate.a = 0.0

	active_tween = create_tween()
	active_tween.tween_property(
		self,
		"modulate:a",
		1.0,
		0.22
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	active_tween.tween_interval(3.0)
	active_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		0.55
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	active_tween.tween_callback(
		_hide_toast
	)


func _hide_toast() -> void:
	visible = false
