extends Node2D
## Edge of the Woods: tells the camera how big the level is (so it never shows past the ends)
## and fades the level name in and out at the start.

@export var level_width: int = 2560
@export var level_height: int = 720


func _ready() -> void:
	$Player.set_camera_limits(0, 0, level_width, level_height)
	var title: Label = $TitleLayer/Title
	title.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(title, "modulate:a", 1.0, 0.8)
	tween.tween_interval(1.8)
	tween.tween_property(title, "modulate:a", 0.0, 1.0)
