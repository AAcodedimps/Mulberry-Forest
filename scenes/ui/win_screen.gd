extends CanvasLayer
## The win screen. When the wanderer has walked out through the gate, the forest's lights
## slowly fade to dark, then "You escaped the forest" appears with the run's time, the number
## of mistakes and ghosts beaten, plus a "Clean Escape" badge if no ghost was ever made.
## "Play again" (or R, handled by the pause menu script) restarts the level.

@onready var fade: ColorRect = $Fade
@onready var center: Control = $Center
@onready var stats: Label = $Center/Box/Stats
@onready var badge: Control = $Center/Box/Badge
@onready var play_again: Button = $Center/Box/PlayAgain


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	play_again.pressed.connect(_restart)


func show_win(time_seconds: float, mistakes: int, ghosts_beaten: int, clean_escape: bool, fade_time: float) -> void:
	add_to_group("run_over")   # stops Esc from unpausing behind the win screen
	visible = true
	fade.modulate.a = 0.0
	center.modulate.a = 0.0
	var total: int = int(time_seconds)
	stats.text = "Time: %d:%02d\nMistakes: %d\nGhosts beaten: %d" % [int(total / 60.0), total % 60, mistakes, ghosts_beaten]
	badge.visible = clean_escape
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, fade_time)
	tween.tween_callback(func(): get_tree().paused = true)
	tween.tween_property(center, "modulate:a", 1.0, 0.8)
	tween.tween_callback(play_again.grab_focus)


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
