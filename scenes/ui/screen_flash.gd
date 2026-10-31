extends CanvasLayer
## A full-screen white flash. Anything can trigger it with
## get_tree().call_group("screen_flash", "flash"); the hole does this when you fall in.

@onready var white: ColorRect = $White


func _ready() -> void:
	add_to_group("screen_flash")
	white.modulate.a = 0.0


func flash() -> void:
	var tween := create_tween()
	white.modulate.a = 1.0
	tween.tween_property(white, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
