extends CanvasLayer
## Shows a short reminder of the main controls in the top-left corner when the level starts,
## keeps it up for `show_time` seconds, then fades it out. It hides while the game is paused or
## over (the pause menu has the full Controls screen), and its timer waits too.

@export var show_time: float = 12.0
@export var fade_time: float = 1.5

@onready var panel: Control = $Panel


func _ready() -> void:
	panel.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(show_time)
	tween.tween_property(panel, "modulate:a", 0.0, fade_time)
	tween.tween_callback(panel.hide)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		visible = false
	elif what == NOTIFICATION_UNPAUSED:
		visible = true
