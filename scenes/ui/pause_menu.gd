extends CanvasLayer
## The pause menu and the "always available" keys. It keeps running while the game is paused.
##  - Esc (Start on a gamepad) pauses: Resume, Restart, Controls, Quit to title.
##  - R (Back on a gamepad) restarts straight away in a brand new random forest.
## When the run is over (caught, or escaped), Esc does nothing; the end screen has its own buttons.

const UiStyle = preload("res://scenes/ui/ui_style.gd")
const TITLE := "res://scenes/ui/title_screen.tscn"

@onready var box: VBoxContainer = $Center/Box
@onready var controls = $Controls

var _resume: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$Center.theme = UiStyle.theme()
	_resume = UiStyle.button("Resume")
	_resume.pressed.connect(_set_paused.bind(false))
	var restart := UiStyle.button("Restart")
	restart.pressed.connect(restart_new_forest)
	var ctrl := UiStyle.button("Controls")
	ctrl.pressed.connect(_open_controls)
	var quit := UiStyle.button("Quit to title")
	quit.pressed.connect(_quit_to_title)
	for b in [_resume, restart, ctrl, quit]:
		box.add_child(b)
	controls.closed.connect(_close_controls.bind(ctrl))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if controls.visible:
			return   # the controls screen closes itself
		if not get_tree().get_nodes_in_group("run_over").is_empty():
			return  # the run is over: Esc does nothing, use the end screen
		get_viewport().set_input_as_handled()
		_set_paused(not get_tree().paused)
	elif event.is_action_pressed("restart") and not controls.visible:
		get_viewport().set_input_as_handled()   # before reloading: afterwards this node is gone
		restart_new_forest()


func _set_paused(on: bool) -> void:
	get_tree().paused = on
	visible = on
	$Center.visible = true
	if on:
		_resume.grab_focus()


func _open_controls() -> void:
	$Center.visible = false
	controls.open()


func _close_controls(button: Button) -> void:
	$Center.visible = true
	button.grab_focus()


## R, Retry, Play again and Restart all come here: a brand new random forest, everything reset.
func restart_new_forest() -> void:
	ForestRun.new_forest()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _quit_to_title() -> void:
	get_tree().paused = false
	Powers.reset()
	get_tree().change_scene_to_file(TITLE)
