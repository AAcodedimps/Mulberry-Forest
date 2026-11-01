extends Node2D
## Edge of the Woods: tells the camera how big the level is, fades the level name in and out,
## keeps the run's stats (time, mistakes, ghosts beaten) and plays the escape when the stone
## gate opens: ghosts freeze, the wanderer walks out through the arch on their own, the
## forest fades to dark and the win screen appears.

@export var level_width: int = 3600
@export var level_height: int = 720
@export var escape_walk_speed: float = 150.0  ## How fast the wanderer walks out through the gate.
@export var fade_time: float = 2.5            ## How long the forest takes to fade to dark at the end.

var _time: float = 0.0
var _timing: bool = true
var _mistakes: int = 0
var _beaten := {}   # every ghost beaten with a stone, counted once


func _ready() -> void:
	Powers.reset()   # every run starts with no powers on
	$Player.set_camera_limits(0, 0, level_width, level_height)
	var title: Label = $TitleLayer/Title
	title.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(title, "modulate:a", 1.0, 0.8)
	tween.tween_interval(1.8)
	tween.tween_property(title, "modulate:a", 0.0, 1.0)
	GameEvents.deadly_mistake.connect(_on_mistake)
	GameEvents.clumsy_mistake.connect(_on_mistake)
	GameEvents.ghost_beaten.connect(_on_ghost_beaten)
	$StoneGate.opening.connect(_on_gate_opening)


func _process(delta: float) -> void:
	if _timing:
		_time += delta   # stops while paused, since this node pauses with the game


func _on_mistake() -> void:
	_mistakes += 1


func _on_ghost_beaten(ghost) -> void:
	_beaten[ghost.get_instance_id()] = true


func _on_gate_opening() -> void:
	_timing = false
	$Ghosts.freeze_all()
	var player = $Player
	player.lock_controls()
	await get_tree().create_timer($StoneGate.open_time).timeout
	# Let the wanderer walk past the right edge of the level; the camera stays at the gate.
	$LevelBounds/RightWall.set_deferred("disabled", true)
	player.start_auto_walk(escape_walk_speed)
	while player.global_position.x < level_width + 80.0:
		await get_tree().physics_frame
	player.start_auto_walk(0.0)
	player.visible = false
	$WinScreen.show_win(_time, _mistakes, _beaten.size(), $Ghosts.ghosts_raised() == 0, fade_time)
