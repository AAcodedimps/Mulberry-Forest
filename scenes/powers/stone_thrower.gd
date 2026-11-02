extends Node2D
const Circles = preload("res://scripts/circles.gd")
## The wanderer's stone pouch and throwing arm (a child of the Player).
## Hold F (X on gamepad) to aim: a dotted arc shows where the stone will fly, and W/S
## (or the right stick) tilt the arc up and down. Release F to throw in the direction the
## wanderer faces. With no stones, pressing F just shakes the stone counter.

# ======================= TUNING =======================
@export var max_stones: int = 5              ## How many stones you can carry.
@export var throw_strength: float = 720.0    ## Launch speed of a stone (pixels/second). Higher = flies further.
@export var arc_gravity: float = 1300.0      ## How quickly stones curve down (pixels/second²). Higher = shorter, steeper arcs.
@export var min_aim_angle: float = -15.0     ## Lowest aim, in degrees above straight ahead (negative = aim downwards).
@export var max_aim_angle: float = 70.0      ## Highest aim, in degrees above straight ahead.
@export var stun_time: float = 3.0           ## A killer ghost hit by a stone is stunned this many seconds...
@export var knock_back_time: float = 3.0     ## ...and pushed back along its path by this many seconds of its travel.
# ======================================================
@export var start_aim_angle: float = 30.0    ## Aim angle when you start aiming the first time.
@export var aim_turn_speed: float = 90.0     ## How fast W/S tilt the arc (degrees per second).
@export var aim_walk_multiplier: float = 0.5 ## Walking speed while aiming (0.5 = half speed).
@export var tap_time: float = 0.2            ## Under the mulberry tree: letting go of F within this many seconds counts as a tap (shake the tree); holding longer aims as normal.

const STONE_SCENE := preload("res://scenes/powers/thrown_stone.tscn")
const HAND := Vector2(26, -72)          # where the stone leaves the hand (facing right)
const PREVIEW_STEP := 1.0 / 30.0        # seconds between dots in the aim arc
const GROUND_MASK := 1 | 4              # world + branch platforms

var stones: int = 0
var aim_angle: float = 30.0
var _aiming: bool = false
var _preview := PackedVector2Array()    # arc points (global)
var _preview_lands: bool = false
var current_tree = null                 # the mulberry tree we're standing under (set by the tree)
var _tap_timer: float = -1.0            # >= 0 while F is down under the tree and we don't know yet if it's a tap

@onready var player = get_parent()


func _ready() -> void:
	aim_angle = start_aim_angle
	_notify_counter.call_deferred()


func is_aiming() -> bool:
	return _aiming


## Adds one stone if there's room. Returns false when the pouch is full.
func add_stone() -> bool:
	if stones >= max_stones:
		return false
	stones += 1
	_notify_counter()
	return true


## Takes one stone out of the pouch (the mulberry tree uses this). Returns false if empty.
func use_stone() -> bool:
	if stones <= 0:
		return false
	stones -= 1
	_notify_counter()
	return true


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("throw"):
		if stones <= 0:
			get_tree().call_group("stone_counter", "shake")
			if current_tree != null:
				get_tree().call_group("message_hud", "show_message", "You need a stone to shake the tree")
		elif player.can_aim():
			if current_tree != null:
				_tap_timer = 0.0     # under the tree: wait to see if this is a tap or a hold
			else:
				_aiming = true
	if _tap_timer >= 0.0:
		_tap_timer += delta
		if not player.can_aim():
			_tap_timer = -1.0
		elif not Input.is_action_pressed("throw"):
			_tap_timer = -1.0
			if current_tree != null:
				current_tree.try_shake(player)   # quick tap: throw a stone up into the tree
		elif _tap_timer >= tap_time:
			_tap_timer = -1.0
			_aiming = true                       # held: aim at ghosts like normal
	if _aiming:
		if not player.can_aim():
			_aiming = false   # got tripped or shoved: aiming is cancelled
		else:
			var tilt: float = Input.get_axis("aim_down", "aim_up")
			aim_angle = clampf(aim_angle + tilt * aim_turn_speed * delta, min_aim_angle, max_aim_angle)
			_update_preview()
			if not Input.is_action_pressed("throw"):
				_throw()
				_aiming = false
	queue_redraw()


func _launch_point() -> Vector2:
	return player.global_position + Vector2(HAND.x * player.facing, HAND.y)


func _launch_velocity() -> Vector2:
	var a: float = deg_to_rad(aim_angle)
	return Vector2(cos(a) * player.facing, -sin(a)) * throw_strength


## Works out the dotted arc by stepping the flight the same way a real stone moves.
func _update_preview() -> void:
	_preview.clear()
	_preview_lands = false
	var space := get_world_2d().direct_space_state
	var p: Vector2 = _launch_point()
	var v: Vector2 = _launch_velocity()
	_preview.append(p)
	for i in 60:
		v.y += arc_gravity * PREVIEW_STEP
		var np: Vector2 = p + v * PREVIEW_STEP
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters2D.create(p, np, GROUND_MASK))
		if not hit.is_empty():
			_preview.append(hit.position)
			_preview_lands = true
			return
		_preview.append(np)
		p = np


func _throw() -> void:
	Sfx.play("throw")
	stones -= 1
	_notify_counter()
	var stone = STONE_SCENE.instantiate()
	stone.velocity = _launch_velocity()
	stone.gravity = arc_gravity
	stone.stun_time = stun_time
	stone.knock_back_time = knock_back_time
	player.get_parent().add_child(stone)
	stone.global_position = _launch_point()


func _notify_counter() -> void:
	get_tree().call_group("stone_counter", "set_stones", stones, max_stones)


func _draw() -> void:
	if not _aiming or _preview.is_empty():
		return
	# Stone held in the hand
	var hand: Vector2 = to_local(_launch_point())
	Circles.circle(self, hand, 6.0, Color("8e8e96"))
	Circles.circle(self, hand + Vector2(-1.5, -1.5), 2.0, Color("cfcfd6"))
	# Dotted arc, fading out toward the end
	var n: int = _preview.size()
	for i in range(1, n, 2):
		var a: float = 1.0 - float(i) / float(n) * 0.6
		Circles.circle(self, to_local(_preview[i]), 3.0, Color(1.0, 0.97, 0.85, a))
	if _preview_lands:
		var land: Vector2 = to_local(_preview[n - 1])
		draw_arc(land, 9.0, 0.0, TAU, 20, Color(1.0, 0.95, 0.7, 0.9), 2.0)
