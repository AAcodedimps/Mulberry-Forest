extends Node
## The forest's memory. Every few physics frames it writes down where the wanderer is,
## but only if they have moved since the last point, so standing still adds nothing.
## When the wanderer falls in a hole, the fall is cut out and the path continues
## from the spot where they reappeared. Killer ghosts follow this list of points.

@export var player_path: NodePath
@export var record_every_frames: int = 3   ## Record a point every this many physics frames.
@export var min_step: float = 3.0          ## Ignore movement smaller than this (pixels).

var points := PackedVector2Array()
var player = null
var _last_floor_index: int = 0   # last point recorded while standing on solid ground
var _frame: int = 0


func _ready() -> void:
	player = get_node(player_path)
	points.append(player.global_position)
	player.respawned.connect(_on_player_respawned)


func get_point(i: int) -> Vector2:
	return points[clampi(i, 0, points.size() - 1)]


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame % record_every_frames != 0:
		return
	var pos: Vector2 = player.global_position
	if pos.distance_to(points[points.size() - 1]) >= min_step:
		points.append(pos)
	if player.is_on_floor():
		_last_floor_index = points.size() - 1


func _on_player_respawned(pos: Vector2) -> void:
	# Cut away everything since we last stood on ground (the fall), then continue from here.
	points.resize(_last_floor_index + 1)
	points.append(pos)
	_last_floor_index = points.size() - 1
