extends Node2D
## Raises killer ghosts. Every time GameEvents.deadly_mistake is sent, a new ghost rises at the
## start of the level and follows the recorded path. It also updates the ghost counter and
## message, and ends the run when a ghost catches the wanderer.

@export var ghost_scene: PackedScene
@export var player_path: NodePath
@export var recorder_path: NodePath
@export var hud_path: NodePath
@export var game_over_path: NodePath

var player = null
var recorder = null
var hud = null
var game_over = null
var _count: int = 0    # ghosts raised so far (decides how fast the next one is)
var _alive: int = 0    # ghosts currently chasing (shown on screen)
var _run_over: bool = false


func _ready() -> void:
	player = get_node(player_path)
	recorder = get_node(recorder_path)
	hud = get_node(hud_path)
	game_over = get_node(game_over_path)
	GameEvents.deadly_mistake.connect(raise_ghost)


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
	hud.set_ghost_count(_alive)
	hud.show_message("A killer ghost has risen...\nJump on its head (Space) to squash it!")


func _on_ghost_squashed(_ghost) -> void:
	_alive -= 1
	hud.set_ghost_count(_alive)
	hud.show_message("Ghost squashed!")


func _on_ghost_caught_player(ghost) -> void:
	if _run_over:
		return
	_run_over = true
	ghost.play_stab()
	game_over.show_game_over()


# ---- TEST ONLY: press G to raise a killer ghost on purpose. Delete this function to remove it. ----
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_G:
		raise_ghost()
