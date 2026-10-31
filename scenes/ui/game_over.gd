extends CanvasLayer
## The "caught" screen. When a ghost reaches the wanderer it freezes the game, flashes the
## screen red and shows "Your mistake caught you" with a Retry button (R also restarts,
## via the pause menu script). Restarting reloads the level, so all ghosts are gone.

@onready var red: ColorRect = $Red
@onready var box: Control = $Center
@onready var retry: Button = $Center/Box/Retry


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	retry.pressed.connect(_restart)


func show_game_over() -> void:
	add_to_group("run_over")   # tells the pause menu not to unpause
	visible = true
	get_tree().paused = true
	red.modulate.a = 1.0
	box.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(red, "modulate:a", 0.45, 0.7)
	tween.parallel().tween_property(box, "modulate:a", 1.0, 0.5).set_delay(0.25)
	retry.grab_focus()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
