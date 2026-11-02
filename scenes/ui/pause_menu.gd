extends CanvasLayer
## Handles the two "always available" keys: Esc pauses/unpauses the game (showing this overlay)
## and R restarts the level in a brand new random forest. It keeps running while the game is paused.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if not get_tree().get_nodes_in_group("run_over").is_empty():
			return  # the run is over: Esc does nothing, use Retry or R
		get_tree().paused = not get_tree().paused
		visible = get_tree().paused
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()   # before reloading: afterwards this node is gone
		ForestRun.new_forest()   # R always builds a brand new random forest
		get_tree().paused = false
		get_tree().reload_current_scene()
