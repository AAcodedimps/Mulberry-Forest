extends CanvasLayer
## Shows the three main controls in the top-left corner when the level starts. Once Moriko has
## walked `fade_distance` pixels away from where she started, it fades out for good. It hides
## while the game is paused or over (the pause menu has the full Controls screen).

# ======================= TUNING =======================
@export var fade_distance: float = 350.0   ## How far (pixels) Moriko walks from the start before the hint fades.
@export var fade_time: float = 1.5         ## Seconds the fade-out takes.
# ======================================================

@onready var panel: Control = $Panel

var _player: Node2D = null
var _start := Vector2.ZERO
var _fading: bool = false


func _ready() -> void:
	panel.modulate.a = 1.0


func _process(_delta: float) -> void:
	if _fading:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player != null:
			_start = _player.global_position
		return
	if _player.global_position.distance_to(_start) > fade_distance:
		_fading = true
		var tween := create_tween()
		tween.tween_property(panel, "modulate:a", 0.0, fade_time)
		tween.tween_callback(panel.hide)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		visible = false
	elif what == NOTIFICATION_UNPAUSED:
		visible = true
