extends CanvasLayer
## Shows the controls in the top-left corner when the level starts, keeps them up for
## `show_time` seconds, then fades them out. The timer pauses while the game is paused.

@export var show_time: float = 12.0
@export var fade_time: float = 1.5

@onready var panel: Control = $Panel


func _ready() -> void:
	panel.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(show_time)
	tween.tween_property(panel, "modulate:a", 0.0, fade_time)
	tween.tween_callback(panel.hide)
