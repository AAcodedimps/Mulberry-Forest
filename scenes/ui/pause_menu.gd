extends CanvasLayer
## Handles the two "always available" keys: Esc pauses/unpauses the game (showing this overlay)
## and R restarts the level. It keeps running while the game is paused.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
		visible = get_tree().paused
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart"):
		get_tree().paused = false
		get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()
