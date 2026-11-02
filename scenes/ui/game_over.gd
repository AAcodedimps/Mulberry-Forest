extends CanvasLayer
## The "caught" screen. When a ghost reaches the wanderer it freezes the game, flashes the
## screen red and shows "Your mistake caught you" with the forest's number ("Forest #4821").
## Retry (or R, via the pause menu script) builds a brand new random forest; T tries this same
## forest again. Restarting reloads the level, so all ghosts are gone.

@onready var red: ColorRect = $Red
@onready var box: Control = $Center
@onready var retry: Button = $Center/Box/Retry
@onready var hint: Label = $Center/Box/Hint

var _forest_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	retry.pressed.connect(_restart)
	_forest_label = make_forest_label($Center/Box)
	$Center/Box.move_child(_forest_label, 1)   # just under the title


func show_game_over() -> void:
	add_to_group("run_over")   # tells the pause menu not to unpause
	visible = true
	get_tree().paused = true
	_forest_label.text = forest_text()
	hint.text = "or press R for a new forest\nT: try this forest again" if ForestRun.forest_number > 0 else "or press R"
	red.modulate.a = 1.0
	box.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(red, "modulate:a", 0.45, 0.7)
	tween.parallel().tween_property(box, "modulate:a", 1.0, 0.5).set_delay(0.25)
	retry.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and is_replay_key(event):
		get_viewport().set_input_as_handled()
		replay_same_forest(get_tree())


func _restart() -> void:
	ForestRun.new_forest()
	get_tree().paused = false
	get_tree().reload_current_scene()


# ---- shared with the win screen ----
## "Forest #4821" (empty on the old test level, which isn't random).
static func forest_text() -> String:
	return "Forest #%d" % ForestRun.forest_number if ForestRun.forest_number > 0 else ""


## A small label for the forest's number, added to `parent`.
static func make_forest_label(parent: Node) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85, 0.85))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.06, 1.0))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_font_size_override("font_size", 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


## True for a fresh press of T.
static func is_replay_key(event: InputEvent) -> bool:
	var key := event as InputEventKey
	return key != null and key.pressed and not key.echo and key.physical_keycode == KEY_T and ForestRun.forest_number > 0


## Reloads the level and builds this same forest again.
static func replay_same_forest(tree: SceneTree) -> void:
	ForestRun.replay_same()
	tree.paused = false
	tree.reload_current_scene()
