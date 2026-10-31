extends CharacterBody2D
## The wanderer. Handles running, the variable-height jump (with coyote time and jump buffering),
## planting feet, climbing vines, tripping over trunks, and being put back after falling in a hole.

# ======================= TUNING: change these to adjust the feel =======================
@export var run_speed: float = 260.0    ## Top running speed, in pixels per second.
@export var jump_height: float = 150.0  ## Height of a full (held) jump, in pixels. A quick tap gives a small hop.
@export var climb_speed: float = 150.0  ## Speed going up and down vines, in pixels per second.
@export var trip_speed: float = 230.0   ## Running into a trunk at this speed or faster makes you trip.
# =======================================================================================

@export_group("Fine tuning")
@export var ground_accel: float = 1800.0      ## How fast you speed up on the ground.
@export var ground_decel: float = 2600.0      ## How fast you slow down when you let go.
@export var turn_accel: float = 3400.0        ## How fast you turn around.
@export var air_accel: float = 1300.0         ## Steering control in the air.
@export var time_to_peak: float = 0.36        ## Seconds to reach the top of a full jump.
@export var fall_gravity_mult: float = 1.7    ## Falling is faster than rising (snappier jumps).
@export var jump_cut: float = 0.45            ## Upward speed kept when you let go of jump early.
@export var max_fall_speed: float = 900.0
@export var coyote_time: float = 0.1          ## Grace time to still jump after running off an edge.
@export var jump_buffer_time: float = 0.1     ## Pressing jump just before landing still counts.
@export var trip_duration: float = 1.0
@export var blink_duration: float = 1.5

const LAYER_WORLD := 1
const LAYER_PLATFORMS := 4
const LAYER_HOLE_LID := 8

enum State { NORMAL, CLIMBING, TRIPPED }

var state: State = State.NORMAL
var facing: int = 1
var planted: bool = false
var last_floor_x: float = 0.0   ## Where we last stood on solid ground (holes use this).
var current_vine = null  # the vine we are touching (a Vine node)

var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _trip_timer: float = 0.0
var _blink_timer: float = 0.0
var _regrab_timer: float = 0.0
var _start_position: Vector2

@onready var look = $Look  # the drawing node (wanderer_look.gd)
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	_start_position = global_position
	last_floor_x = global_position.x
	_update_collision_mask()
	camera.reset_smoothing()


func set_camera_limits(left: int, top: int, right: int, bottom: int) -> void:
	camera.limit_left = left
	camera.limit_top = top
	camera.limit_right = right
	camera.limit_bottom = bottom
	camera.reset_smoothing()


func _jump_velocity() -> float:
	return 2.0 * jump_height / time_to_peak


func _jump_gravity() -> float:
	return 2.0 * jump_height / (time_to_peak * time_to_peak)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	match state:
		State.NORMAL:
			_process_normal(delta)
		State.CLIMBING:
			_process_climbing(delta)
		State.TRIPPED:
			_process_tripped(delta)
	move_and_slide()
	if is_on_floor():
		_coyote = coyote_time
		last_floor_x = global_position.x
	if global_position.y > 1000.0:
		respawn_at(_start_position)  # safety net if we ever fall out of the world
	_update_look()


func _tick_timers(delta: float) -> void:
	_coyote -= delta
	_jump_buffer -= delta
	_regrab_timer -= delta
	if _blink_timer > 0.0:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_update_collision_mask()
	if state == State.TRIPPED:
		_trip_timer -= delta


# ---------------------------------------------------------------- normal movement
func _process_normal(delta: float) -> void:
	var dir: float = Input.get_axis("move_left", "move_right")
	var on_floor: bool = is_on_floor()

	if Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time

	# Grab a vine with up (or down while in the air / standing on top of it).
	if current_vine != null and _regrab_timer <= 0.0:
		var vine_above: bool = current_vine.get_top_y() < global_position.y - 8.0
		var vine_below: bool = current_vine.get_bottom_y() > global_position.y + 4.0
		var wants_up: bool = Input.is_action_pressed("move_up") and vine_above
		var wants_down: bool = Input.is_action_pressed("move_down") and vine_below and (not on_floor or vine_above == false)
		if wants_up or wants_down:
			_start_climbing()
			return

	# Hold down on the ground: plant your feet and stop dead.
	planted = on_floor and Input.is_action_pressed("move_down")
	if planted:
		velocity.x = 0.0
	else:
		var target: float = dir * run_speed
		var rate: float
		if not on_floor:
			rate = air_accel if dir != 0.0 else air_accel * 0.5
		elif dir == 0.0:
			rate = ground_decel
		elif velocity.x != 0.0 and signf(dir) != signf(velocity.x):
			rate = turn_accel
		else:
			rate = ground_accel
		velocity.x = move_toward(velocity.x, target, rate * delta)
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1

	# Gravity: lighter going up, heavier coming down.
	var g: float = _jump_gravity() if velocity.y < 0.0 else _jump_gravity() * fall_gravity_mult
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)

	# Jump (works during coyote time and with a buffered press).
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = -_jump_velocity()
		_jump_buffer = 0.0
		_coyote = 0.0
		if not Input.is_action_pressed("jump"):
			velocity.y *= jump_cut  # button was already let go: small hop
	# Let go early = shorter jump.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut


# ---------------------------------------------------------------- climbing
func _start_climbing() -> void:
	state = State.CLIMBING
	planted = false
	velocity = Vector2.ZERO
	_coyote = 0.0
	_jump_buffer = 0.0
	_update_collision_mask()


func _stop_climbing() -> void:
	state = State.NORMAL
	_update_collision_mask()


func _process_climbing(delta: float) -> void:
	if current_vine == null:
		# Climbed off the top or bottom of the vine.
		_stop_climbing()
		velocity.y = 0.0
		return
	global_position.x = move_toward(global_position.x, current_vine.global_position.x, 600.0 * delta)
	velocity.x = 0.0
	var v: float = Input.get_axis("move_up", "move_down")
	velocity.y = v * climb_speed
	var dir: float = Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
	if Input.is_action_just_pressed("jump"):
		_stop_climbing()
		velocity.y = -_jump_velocity() * 0.75
		velocity.x = dir * run_speed
		_regrab_timer = 0.25
		return
	if is_on_floor() and v > 0.0:
		_stop_climbing()


func enter_vine(vine) -> void:
	current_vine = vine


func leave_vine(vine) -> void:
	if current_vine == vine:
		current_vine = null


# ---------------------------------------------------------------- tripping
## Called by a tree trunk. Returns true if we were going fast enough to trip.
func try_trip() -> bool:
	if state != State.NORMAL or not is_on_floor():
		return false
	if absf(velocity.x) < trip_speed:
		return false
	state = State.TRIPPED
	planted = false
	_trip_timer = trip_duration
	velocity.x = 0.0
	return true


func _process_tripped(delta: float) -> void:
	velocity.x = 0.0
	velocity.y = minf(velocity.y + _jump_gravity() * fall_gravity_mult * delta, max_fall_speed)
	if _trip_timer <= 0.0:
		state = State.NORMAL


# ---------------------------------------------------------------- holes / respawn
func is_blinking() -> bool:
	return _blink_timer > 0.0


## Put the wanderer back at a safe spot and blink (can't fall in a hole while blinking).
func respawn_at(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	state = State.NORMAL
	planted = false
	current_vine = null
	_coyote = 0.0
	_jump_buffer = 0.0
	_blink_timer = blink_duration
	last_floor_x = pos.x
	_update_collision_mask()


func _update_collision_mask() -> void:
	var m: int = LAYER_WORLD
	if state != State.CLIMBING:
		m |= LAYER_PLATFORMS     # branch platforms only block us when we're not on a vine
	if _blink_timer > 0.0:
		m |= LAYER_HOLE_LID      # while blinking, holes have an invisible lid
	collision_mask = m


# ---------------------------------------------------------------- visuals
func _update_look() -> void:
	look.facing = facing
	var pose: String = "idle"
	if state == State.TRIPPED:
		pose = "tripped"
	elif state == State.CLIMBING:
		pose = "climb_move" if velocity.y != 0.0 else "climb"
	elif not is_on_floor():
		pose = "jump" if velocity.y < 0.0 else "fall"
	elif planted:
		pose = "planted"
	elif absf(velocity.x) > 10.0:
		pose = "run"
	look.pose = pose
	look.speed_ratio = clampf(absf(velocity.x) / run_speed, 0.0, 1.0)
	if _blink_timer > 0.0:
		look.visible = fmod(_blink_timer, 0.16) > 0.08
	else:
		look.visible = true
