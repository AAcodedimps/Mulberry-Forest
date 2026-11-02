extends Node2D
## The title screen: "Mulberry Forest" in big soft glowing letters over the dusk forest, with
## drifting fireflies and Start / Controls / Quit. Start shows two short lines of story, then the
## forest begins (any key skips the story).

const UiStyle = preload("res://scenes/ui/ui_style.gd")
const LEVEL := "res://scenes/levels/mulberry_forest.tscn"
const STORY := ["You are lost in an enchanted forest.", "The old stone gate will only open for 5 mulberries."]

# ======================= TUNING =======================
@export var story_line_time: float = 2.6   ## Seconds each story line stays before the next one (any key skips).
# ======================================================

@onready var ui: Control = $UI/Root
@onready var title: Label = $UI/Root/Title
@onready var buttons: VBoxContainer = $UI/Root/Buttons
@onready var controls = $UI/Controls
@onready var story: Control = $UI/Story

var _t: float = 0.0
var _starting: bool = false
var _skip: bool = false


func _ready() -> void:
	get_tree().paused = false
	Powers.reset()
	Sfx.start_music()
	ui.theme = UiStyle.theme()
	var start := UiStyle.button("Start")
	start.pressed.connect(_on_start)
	var ctrl := UiStyle.button("Controls")
	ctrl.pressed.connect(func(): controls.open())
	var quit := UiStyle.button("Quit")
	quit.pressed.connect(func(): get_tree().quit())
	for b in [start, ctrl, quit]:
		buttons.add_child(b)
	if OS.has_feature("web"):
		quit.visible = false   # browsers can't be quit from a game
	controls.visible = false
	controls.closed.connect(func(): start.grab_focus())
	story.visible = false
	start.grab_focus.call_deferred()
	ui.modulate.a = 0.0
	create_tween().tween_property(ui, "modulate:a", 1.0, 1.2)


func _process(delta: float) -> void:
	_t += delta
	# The title glows softly, breathing in and out.
	var glow: float = 0.5 + 0.5 * sin(_t * 1.3)
	title.add_theme_color_override("font_shadow_color", Color(1.0, 0.78, 0.5, 0.25 + 0.25 * glow))
	title.add_theme_constant_override("shadow_outline_size", int(30.0 + 14.0 * glow))
	# The forest drifts very gently.
	$Far.position.x = -260.0 + sin(_t * 0.05) * 240.0 * 0.3
	$Mid.position.x = -260.0 + sin(_t * 0.05) * 240.0 * 0.6
	$Near.position.x = -260.0 + sin(_t * 0.05) * 240.0


func _on_start() -> void:
	if _starting:
		return
	_starting = true
	ForestRun.new_forest()
	story.visible = true
	story.modulate.a = 0.0
	var lines: Array = [$UI/Story/Box/Line1, $UI/Story/Box/Line2]
	for i in lines.size():
		lines[i].text = STORY[i]
		lines[i].modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(story, "modulate:a", 1.0, 0.8)
	for l in lines:
		tw.tween_property(l, "modulate:a", 1.0, 1.0)
		tw.tween_interval(story_line_time - 1.0)
	tw.tween_interval(0.8)
	await tw.finished
	_go()


func _unhandled_input(event: InputEvent) -> void:
	# Any key or button skips the story.
	if _starting and not _skip and event.is_pressed() and not event.is_echo() and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton):
		get_viewport().set_input_as_handled()
		_skip = true
		_go()


func _go() -> void:
	if not is_inside_tree() or get_meta("leaving", false):
		return
	set_meta("leaving", true)
	get_tree().change_scene_to_file(LEVEL)
