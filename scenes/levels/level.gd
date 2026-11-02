extends Node2D
## The level: builds the random forest (if there's a Forest node), tells the camera how big the
## level is, shows each zone's name when you walk in,
## keeps the run's stats (time, mistakes, ghosts beaten) and plays the escape when the stone
## gate opens: ghosts freeze, the wanderer walks out through the arch on their own, the
## forest fades to dark and the win screen appears.

@export var level_width: int = 4700
@export var level_height: int = 720
@export var escape_walk_speed: float = 150.0  ## How fast the wanderer walks out through the gate.
@export var fade_time: float = 2.5            ## How long the forest takes to fade to dark at the end.
@export var gate_path: NodePath = ^"StoneGate"  ## The stone gate that ends the level.

## Zones (zone.gd nodes) sorted from left to right; the one the wanderer is in shows its name.
var _zones: Array = []
var _zone_index: int = -1
var _zones_seen := {}
var _gate = null

var _time: float = 0.0
var _timing: bool = true
var _mistakes: int = 0
var _beaten := {}   # every ghost beaten with a stone, counted once


func _ready() -> void:
	Powers.reset()   # every run starts with no powers on
	var builder = get_node_or_null("Forest")
	if builder != null and builder.has_method("build"):
		# The random forest: build it first, then fit the level's edges around it.
		level_width = int(builder.build(self))
		$LevelBounds/RightWall.position.x = level_width + 20.0
	$Player.set_camera_limits(0, 0, level_width, level_height)
	if has_node("TitleLayer/Title"):   # the old test strip shows one title instead of zones
		var title: Label = $TitleLayer/Title
		title.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(title, "modulate:a", 1.0, 0.8)
		tween.tween_interval(1.8)
		tween.tween_property(title, "modulate:a", 0.0, 1.0)
	for z in get_tree().get_nodes_in_group("zones"):
		if is_ancestor_of(z):
			_zones.append(z)
	_zones.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	GameEvents.deadly_mistake.connect(_on_mistake)
	GameEvents.clumsy_mistake.connect(_on_mistake)
	GameEvents.ghost_beaten.connect(_on_ghost_beaten)
	_gate = builder.gate if builder != null and builder.get("gate") != null else get_node(gate_path)
	_gate.opening.connect(_on_gate_opening)


func _process(delta: float) -> void:
	if _timing:
		_time += delta   # stops while paused, since this node pauses with the game
	_update_zone()


## Shows a zone's name the first time the wanderer walks into it.
func _update_zone() -> void:
	if _zones.is_empty():
		return
	var x: float = $Player.global_position.x
	var index: int = 0
	for i in _zones.size():
		if x >= _zones[i].global_position.x:
			index = i
	if index == _zone_index:
		return
	_zone_index = index
	if not _zones_seen.has(index):
		_zones_seen[index] = true
		var z = _zones[index]
		var shown: String = z.zone_name
		if z.canopy_name != "" and $Player.global_position.y < 470.0:
			shown = z.canopy_name   # arriving up in the branches
		get_tree().call_group("zone_banner", "show_zone", shown)


## Which zone the wanderer is in (0 = the first). Handy for tests.
func current_zone() -> int:
	return _zone_index


func _on_mistake() -> void:
	_mistakes += 1


func _on_ghost_beaten(ghost) -> void:
	_beaten[ghost.get_instance_id()] = true


func _on_gate_opening() -> void:
	_timing = false
	$Ghosts.freeze_all()
	var player = $Player
	player.lock_controls()
	await get_tree().create_timer(_gate.open_time).timeout
	# Let the wanderer walk past the right edge of the level; the camera stays at the gate.
	$LevelBounds/RightWall.set_deferred("disabled", true)
	player.start_auto_walk(escape_walk_speed)
	while player.global_position.x < level_width + 80.0:
		await get_tree().physics_frame
	player.start_auto_walk(0.0)
	player.visible = false
	$WinScreen.show_win(_time, _mistakes, _beaten.size(), $Ghosts.ghosts_raised() == 0, fade_time)
