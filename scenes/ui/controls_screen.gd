extends Control
## The Controls screen: every keyboard and gamepad control, and a line about the ghosts.
## Used by the title screen and the pause menu. Back (or Esc / B) closes it and sends `closed`.

signal closed

const UiStyle = preload("res://scenes/ui/ui_style.gd")

const KEYBOARD := [
	["Move", "A / D  or  Left / Right"],
	["Jump", "Space  (hold for a higher jump)"],
	["Climb a vine", "W / S  or  Up / Down"],
	["Stop dead", "hold S"],
	["Throw a stone", "hold F, aim with W / S, let go"],
	["Shake a mulberry tree", "tap F under it (uses 1 stone)"],
	["Squash a killer ghost", "jump on its head"],
	["Pause", "Esc"],
	["New forest", "R"],
	["Try the same forest again", "T  (on the end screens)"],
]
const GAMEPAD := [
	["Move / climb", "left stick or D-pad"],
	["Jump", "A"],
	["Throw a stone / shake a tree", "X  (aim with the right stick)"],
	["Pause", "Start"],
	["New forest", "Back / Select"],
]

var _back: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.07, 0.96)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	box.add_child(UiStyle.label("Controls", 48, Color(0.85, 1.0, 0.85)))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 60)
	box.add_child(cols)
	cols.add_child(_column("Keyboard", KEYBOARD))
	cols.add_child(_column("Gamepad", GAMEPAD))
	var ghosts := UiStyle.label("Every mistake becomes a ghost that follows your path.\nRed ghosts kill, green ghosts play tricks.", 24, Color(1.0, 0.88, 0.75))
	box.add_child(ghosts)
	_back = UiStyle.button("Back", 220.0)
	_back.pressed.connect(close)
	box.add_child(_back)


func _column(title: String, rows: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var head := UiStyle.label(title, 28, Color(1.0, 0.92, 0.6))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 3)
	col.add_child(grid)
	for r in rows:
		var a := UiStyle.label(r[0], 19, Color(0.8, 0.95, 0.8))
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var b := UiStyle.label(r[1], 19)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(a)
		grid.add_child(b)
	return col


## Shows the screen and selects Back.
func open() -> void:
	visible = true
	_back.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		close()
