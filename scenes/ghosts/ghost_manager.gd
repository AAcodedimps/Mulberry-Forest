extends Node2D
## Raises the ghosts. Every GameEvents.deadly_mistake raises a killer ghost and every
## GameEvents.clumsy_mistake raises a mischief ghost, both at the start of the level.
## It keeps the on-screen counts up to date, shows the messages, and ends the run when a
## killer ghost catches the wanderer (mischief ghosts never end the run).

@export var ghost_scene: PackedScene          ## The killer ghost scene.
@export var mischief_scene: PackedScene       ## The mischief ghost scene.
@export var player_path: NodePath
@export var recorder_path: NodePath
@export var hud_path: NodePath
@export var game_over_path: NodePath

var player = null
var recorder = null
var hud = null
var game_over = null
var _count: int = 0            # killer ghosts raised so far (decides how fast the next one is)
var _alive: int = 0            # killer ghosts chasing right now
var _mischief_count: int = 0   # mischief ghosts raised so far
var _mischief_alive: int = 0   # mischief ghosts chasing right now
var _run_over: bool = false


func _ready() -> void:
	player = get_node(player_path)
	recorder = get_node(recorder_path)
	hud = get_node(hud_path)
	game_over = get_node(game_over_path)
	GameEvents.deadly_mistake.connect(raise_ghost)
	GameEvents.clumsy_mistake.connect(raise_mischief_ghost)


# ---------------------------------------------------------------- killer ghosts
func raise_ghost() -> void:
	if _run_over:
		return
	_count += 1
	var ghost = ghost_scene.instantiate()
	add_child(ghost)
	ghost.setup(recorder, player, _count)
	ghost.caught_player.connect(_on_ghost_caught_player)
	ghost.squashed.connect(_on_ghost_squashed)
	_alive += 1
	_update_counts()
	hud.show_message("A killer ghost has risen...\nJump on its head (Space) to squash it!")


func _on_ghost_squashed(_ghost) -> void:
	_alive -= 1
	_update_counts()
	hud.show_message("Ghost squashed!")


func _on_ghost_caught_player(ghost) -> void:
	if _run_over:
		return
	_run_over = true
	ghost.play_stab()
	game_over.show_game_over()


# ---------------------------------------------------------------- mischief ghosts
func raise_mischief_ghost() -> void:
	if _run_over:
		return
	_mischief_count += 1
	var ghost = mischief_scene.instantiate()
	add_child(ghost)
	ghost.setup(recorder, player, _mischief_count)
	ghost.trick_played.connect(_on_mischief_trick_played)
	ghost.vanished.connect(_on_mischief_vanished)
	_mischief_alive += 1
	_update_counts()
	hud.show_message("A mischief ghost has risen...")


func _on_mischief_trick_played(_ghost, trick: String) -> void:
	if trick == "steal":
		hud.show_message("The ghost stole a mulberry!")


func _on_mischief_vanished(_ghost) -> void:
	_mischief_alive -= 1
	_update_counts()


func _update_counts() -> void:
	hud.set_counts(_alive, _mischief_alive)


## How many ghosts (killer + mischief) were raised this run.
func ghosts_raised() -> int:
	return _count + _mischief_count


## Used when the wanderer escapes: every ghost stops where it is and no new ones rise.
func freeze_all() -> void:
	_run_over = true
	for ghost in get_children():
		ghost.set_physics_process(false)


# ---- TEST ONLY: G raises a killer ghost, H raises a mischief ghost. Delete this function to remove both. ----
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_G:
		raise_ghost()
	elif key.physical_keycode == KEY_H:
		raise_mischief_ghost()
