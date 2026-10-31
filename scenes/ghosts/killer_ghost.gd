extends Node2D
## A killer ghost: a see-through red sheet ghost with angry eyes and a silver dagger.
## It rises at the start of the level and floats along the wanderer's recorded path at a
## steady speed, straight over holes, over trunks and up vines. If it reaches the
## wanderer it stabs them and sends `caught_player`. If the wanderer lands on its head
## (falling down onto it after a jump), it gets squashed flat and sends `squashed`.

# ======================= TUNING =======================
@export var base_speed: float = 240.0                 ## Speed of the first ghost along your path (pixels/second). Your run_speed is 290.
@export var speed_increase_per_ghost: float = 0.08    ## Each extra ghost is this much faster than the one before (0.08 = 8%).
@export var catch_distance: float = 40.0              ## How close (pixels) a ghost must get to stab you.
@export var stomp_width: float = 48.0                 ## How far left/right of the ghost's centre your feet can land and still squash it.
# ======================================================
@export var rise_time: float = 1.0    ## Seconds spent rising before it starts the chase.
@export var size_scale: float = 2.1   ## Same drawing scale as the wanderer.

signal caught_player(ghost)
signal squashed(ghost)

const BODY := Color(0.93, 0.16, 0.22, 0.72)
const RIM := Color(1.0, 0.62, 0.62, 0.7)
const EYE := Color(0.16, 0.0, 0.03, 0.95)
const PUPIL := Color("ffd23f")
const BLADE := Color("dde5ee")
const BLADE_EDGE := Color("8f9bab")
const GUARD := Color("c9a64a")
const HANDLE := Color("5a3a28")

var ghost_number: int = 1
var speed: float = 320.0
var recorder = null   # the PathRecorder
var player = null

var _index: int = 0        # which path point we're leaving
var _dist: float = 0.0     # how far along the segment to the next point
var _rise: float = 0.0
var _stun: float = 0.0
var _facing: int = 1
var _t: float = 0.0
var _stabbing: bool = false
var _squash: float = -1.0   # -1 = alive; 0..1 = being squashed flat


func _ready() -> void:
	add_to_group("ghosts")
	add_to_group("stone_targets")
	modulate.a = 0.0


# ---------------------------------------------------------------- stones
const FloatingText = preload("res://scenes/ui/floating_text.gd")


## Stone target: true if a stone at `point` touches this ghost's body.
func stone_hit_test(point: Vector2) -> bool:
	if _squash >= 0.0 or _stabbing:
		return false
	return point.distance_to(global_position + Vector2(0, -50)) <= 46.0


## Stone target: a stone stuns the ghost and knocks it back along its path.
func on_stone_hit(stone) -> void:
	stun(stone.stun_time)
	knock_back(stone.knock_back_time)
	GameEvents.report_ghost_beaten(self)
	FloatingText.spawn(get_parent(), global_position, "Stunned!", Color(1.0, 0.85, 0.4))


## Called by the ghost manager right after the ghost is created.
func setup(path_recorder, target, number: int) -> void:
	recorder = path_recorder
	player = target
	ghost_number = number
	speed = base_speed * pow(1.0 + speed_increase_per_ghost, number - 1)
	_index = 0
	_dist = 0.0
	global_position = recorder.get_point(0)


# ---------------------------------------------------------------- for stones / shield later
## Stops the ghost for `seconds`; it looks dizzy and can't stab while stunned.
func stun(seconds: float) -> void:
	_stun = maxf(_stun, seconds)


## Pushes the ghost backwards along its path by the distance it would travel in `seconds`.
func knock_back(seconds: float) -> void:
	_move_along(-speed * seconds)


func is_stunned() -> bool:
	return _stun > 0.0


## Called when this ghost catches the wanderer: thrust the dagger.
func play_stab() -> void:
	_stabbing = true
	queue_redraw()


# ---------------------------------------------------------------- movement
func _physics_process(delta: float) -> void:
	delta *= Powers.world_time_scale()   # Moonpetal slows ghosts down
	_t += delta
	queue_redraw()
	if _squash >= 0.0:
		# Flattening, then gone.
		_squash += delta / 0.35
		modulate.a = clampf(1.0 - _squash, 0.0, 1.0)
		if _squash >= 1.0:
			queue_free()
		return
	if recorder == null or _stabbing or player == null:
		return
	if _rise < rise_time:
		_rise += delta
		modulate.a = clampf(_rise / rise_time, 0.0, 1.0)
		return
	if _is_being_stomped():
		_get_squashed()
		return
	if _stun > 0.0:
		_stun -= delta
		return
	_move_along(speed * delta)
	if global_position.distance_to(player.global_position) <= catch_distance:
		if Powers.has_shield():
			# Bark Shield: bounce off and get knocked back along the path.
			knock_back(Powers.shield_knock_back_time)
			stun(0.5)
			if Powers.shield_block():
				FloatingText.spawn(get_parent(), player.global_position, "Blocked!", Color(0.6, 1.0, 0.65))
		else:
			_stabbing = true
			caught_player.emit(self)


## True when the wanderer is falling down onto the top half of this ghost.
func _is_being_stomped() -> bool:
	if player.is_on_floor() or player.velocity.y <= 0.0:
		return false
	var feet: Vector2 = player.global_position
	var dy: float = global_position.y - feet.y   # how far the feet are above the ghost's base
	return absf(feet.x - global_position.x) <= stomp_width and dy >= 45.0 and dy <= 118.0


func _get_squashed() -> void:
	_squash = 0.0
	remove_from_group("ghosts")   # no more arrow for this one
	remove_from_group("stone_targets")
	player.bounce()
	squashed.emit(self)


## Moves along the recorded path by `distance` pixels (negative = backwards).
func _move_along(distance: float) -> void:
	var pts: PackedVector2Array = recorder.points
	if pts.is_empty():
		return
	if _index >= pts.size() - 1:
		_index = pts.size() - 1
		_dist = 0.0
	var remaining: float = distance
	if remaining >= 0.0:
		while _index < pts.size() - 1:
			var seg_len: float = pts[_index].distance_to(pts[_index + 1])
			_dist = minf(_dist, seg_len)
			if _dist + remaining < seg_len:
				_dist += remaining
				break
			remaining -= seg_len - _dist
			_index += 1
			_dist = 0.0
	else:
		while remaining < 0.0:
			if _dist + remaining >= 0.0:
				_dist += remaining
				break
			remaining += _dist
			if _index == 0:
				_dist = 0.0
				break
			_index -= 1
			_dist = pts[_index].distance_to(pts[_index + 1])
	var p: Vector2 = pts[_index]
	if _index < pts.size() - 1:
		p = p.move_toward(pts[_index + 1], _dist)
	var dx: float = p.x - global_position.x
	if absf(dx) > 0.5:
		_facing = 1 if dx > 0.0 else -1
	global_position = p


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	var bob: float = sin(_t * 3.0 + ghost_number) * 2.0
	var rise_off: float = (1.0 - clampf(_rise / rise_time, 0.0, 1.0)) * 20.0
	var wobble: float = sin(_t * 9.0) * 0.12 if _stun > 0.0 else 0.0
	var flat := Vector2.ONE
	if _squash >= 0.0:
		bob = 0.0
		flat = Vector2(1.0 + _squash * 0.8, maxf(0.15, 1.0 - _squash * 0.85))
	draw_set_transform(Vector2(0, (bob + rise_off) * size_scale), wobble,
		Vector2(size_scale * _facing * flat.x, size_scale * flat.y))

	# Faint red aura
	draw_circle(Vector2(0, -26), 24.0, Color(1, 0.2, 0.2, 0.07))

	# Sheet body: round head, wavy hem
	var body := PackedVector2Array()
	for i in 17:
		var a: float = PI + PI * i / 16.0
		body.append(Vector2(cos(a) * 14.0, -34.0 + sin(a) * 14.0))
	body.append(Vector2(15, -20))
	for i in 13:
		var x: float = 16.0 - 32.0 * i / 12.0
		body.append(Vector2(x, -6.0 + sin(x * 0.6 + _t * 6.0) * 2.5))
	body.append(Vector2(-15, -20))
	draw_colored_polygon(body, BODY)
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, RIM, 1.0)

	# Face
	if _stun > 0.0:
		for ex: float in [3.0, 10.0]:
			for r: float in [1.0, 2.0, 3.0]:
				draw_arc(Vector2(ex, -36), r, _t * 8.0 + r, _t * 8.0 + r + 4.5, 8, EYE, 0.8)
	else:
		for ex: float in [3.0, 10.0]:
			var pts := PackedVector2Array()
			for i in 12:
				var a: float = TAU * i / 12.0
				pts.append(Vector2(ex + cos(a) * 3.0, -35.5 + sin(a) * 2.4))
			draw_colored_polygon(pts, EYE)
			draw_circle(Vector2(ex + 0.6, -35.5), 1.1, PUPIL)
		draw_line(Vector2(-0.5, -41.5), Vector2(6, -38.5), EYE, 1.8)   # angry brows
		draw_line(Vector2(13.5, -41.5), Vector2(7, -38.5), EYE, 1.8)
	draw_polyline(PackedVector2Array([Vector2(2, -28), Vector2(4, -30), Vector2(6, -28),
		Vector2(8, -30), Vector2(10, -28)]), EYE, 1.2)

	# Little arm holding a silver dagger (thrust forward when stabbing)
	var hand := Vector2(21, -20) if _stabbing else Vector2(14, -19)
	var angle: float = 0.0 if _stabbing else -0.7
	draw_circle(hand, 4.0, BODY)
	var grip := Transform2D(angle, hand)
	draw_colored_polygon(grip * PackedVector2Array([Vector2(-6, -1.4), Vector2(0, -1.4), Vector2(0, 1.4), Vector2(-6, 1.4)]), HANDLE)
	draw_colored_polygon(grip * PackedVector2Array([Vector2(0, -2.6), Vector2(14, -0.8), Vector2(17, 0), Vector2(14, 0.8), Vector2(0, 2.6)]), BLADE)
	draw_line(grip * Vector2(1, 0), grip * Vector2(15, 0), BLADE_EDGE, 0.6)
	draw_line(grip * Vector2(0, -4), grip * Vector2(0, 4), GUARD, 2.0)

	# Dizzy stars when stunned
	if _stun > 0.0:
		for k in 3:
			var a: float = _t * 4.0 + k * TAU / 3.0
			var s := Vector2(cos(a) * 13.0, -52.0 + sin(a) * 3.5)
			draw_line(s + Vector2(-2.5, 0), s + Vector2(2.5, 0), PUPIL, 1.2)
			draw_line(s + Vector2(0, -2.5), s + Vector2(0, 2.5), PUPIL, 1.2)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
