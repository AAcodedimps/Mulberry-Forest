extends CharacterBody2D
## The wanderer. Handles running, the variable-height jump (with coyote time and jump buffering),
## planting feet, climbing vines, tripping over trunks, and being put back after falling in a hole.

# ======================= TUNING: change these to adjust the feel =======================
@export var run_speed: float = 290.0    ## Top running speed, in pixels per second.
@export var jump_height: float = 170.0  ## Height of a full (held) jump, in pixels. A quick tap gives a small hop. Keep below 200 so the branch still needs the vine.
@export var climb_speed: float = 170.0  ## Speed going up and down vines, in pixels per second.
@export var trip_speed: float = 255.0   ## Running into a trunk at this speed or faster makes you trip.
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

@export_group("Testing")
@export var start_mulberries: int = 0  ## Mulberries in the basket at the start (set above 0 to test the basket-steal trick).

@export var basket_size: int = 5  ## How many mulberries the basket holds (the gate wants a full basket).

enum State { NORMAL, CLIMBING, TRIPPED, SHOVED, CUTSCENE }

## Sent when Wild Berries cure the wanderer (poison and bee stings are gone).
signal cured

## Sent after the wanderer is put back somewhere (e.g. after a hole). The path recorder uses it.
signal respawned(pos: Vector2)

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
var mulberries: int = 0          ## Mulberries in the basket.
var _basket_trees: Array = []    # the tree each basket berry came from (newest last)
var _auto_walk_speed: float = 0.0  # used while walking out through the gate
var _slow_timer: float = 0.0     # mischief "Slow" trick
var _slow_mult: float = 1.0
var _soak_timer: float = 0.0    # soaked by a flood wave
var _soak_mult: float = 1.0
var _poison_timer: float = 0.0  # poisoned by poison flowers
var _poison_mult: float = 1.0
var _sting_timer: float = 0.0   # stung by bees
var _sting_mult: float = 1.0    # speed for ONE sting; stings stack (2 stings = mult x mult, ...)
var _stings: int = 0            # how many stings right now
var _sting_label: Label         # the little sting number next to the wanderer
var _shove_timer: float = 0.0    # mischief "Shove" trick
var _shove_decel: float = 0.0
var _popup_tween: Tween
var _shake_time: float = 0.0      # screen shake: time left...
var _shake_length: float = 0.0    # ...how long it lasts...
var _shake_strength: float = 0.0  # ...and how strong it starts (pixels)

const DustPuff = preload("res://scenes/player/dust_puff.gd")

@onready var look = $Look  # the drawing node (wanderer_look.gd)
@onready var camera: Camera2D = $Camera2D
@onready var popup: Label = $Popup
@onready var stone_thrower = $StoneThrower  # aiming and throwing stones (stone_thrower.gd)


func _ready() -> void:
	_start_position = global_position
	mulberries = mini(start_mulberries, basket_size)
	popup.modulate.a = 0.0
	_make_sting_label()
	_notify_basket.call_deferred()
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
	# Same as 2 * jump_height / time_to_peak, but Strength Fig can raise the height.
	return sqrt(2.0 * _jump_gravity() * jump_height * Powers.jump_multiplier())


func _jump_gravity() -> float:
	return 2.0 * jump_height / (time_to_peak * time_to_peak)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	var was_on_floor: bool = is_on_floor()
	match state:
		State.NORMAL:
			_process_normal(delta)
		State.CLIMBING:
			_process_climbing(delta)
		State.TRIPPED:
			_process_tripped(delta)
		State.SHOVED:
			_process_shoved(delta)
		State.CUTSCENE:
			velocity = Vector2(_auto_walk_speed, 0.0)   # no gravity: walks straight out of the level
	var fall_speed: float = velocity.y
	move_and_slide()
	if is_on_floor() and not was_on_floor and fall_speed > 260.0 and state != State.CUTSCENE:
		_landed(fall_speed)
	_update_shake(delta)
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
	if _slow_timer > 0.0:
		_slow_timer -= delta
	if _soak_timer > 0.0:
		_soak_timer -= delta
	if _poison_timer > 0.0:
		_poison_timer -= delta
	if _sting_timer > 0.0:
		_sting_timer -= delta
		if _sting_timer <= 0.0:
			_stings = 0   # all the stings wear off together
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

	var aiming: bool = stone_thrower.is_aiming()

	# Grab a vine with up (or down while in the air / standing on top of it). Not while aiming.
	if current_vine != null and _regrab_timer <= 0.0 and not aiming:
		var vine_above: bool = current_vine.get_top_y() < global_position.y - 8.0
		var vine_below: bool = current_vine.get_bottom_y() > global_position.y + 4.0
		var wants_up: bool = Input.is_action_pressed("move_up") and vine_above
		var wants_down: bool = Input.is_action_pressed("move_down") and vine_below and (not on_floor or vine_above == false)
		if wants_up or wants_down:
			_start_climbing()
			return

	# Hold down on the ground: plant your feet and stop dead.
	planted = on_floor and Input.is_action_pressed("move_down") and not aiming
	if planted:
		velocity.x = 0.0
	else:
		var target: float = dir * run_speed * _speed_mult()
		if aiming:
			target *= stone_thrower.aim_walk_multiplier   # walk slower while aiming a stone
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
		_jumped()
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
	velocity.y = v * climb_speed * _speed_mult()
	if stone_thrower.is_aiming():
		velocity.y = 0.0   # W/S aim instead of climbing; just hang on
	var dir: float = Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
	if Input.is_action_just_pressed("jump"):
		_stop_climbing()
		velocity.y = -_jump_velocity() * 0.75
		velocity.x = dir * run_speed
		_regrab_timer = 0.25
		_jumped()
		return
	if is_on_floor() and v > 0.0:
		_stop_climbing()
	elif is_on_floor() and v == 0.0 and dir != 0.0:
		_stop_climbing()   # standing on the ground at the bottom of a vine: walk off it


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
	if Powers.has_shield():
		Powers.shield_block()   # Bark Shield stops trips
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


# ---------------------------------------------------------------- mischief ghost tricks
func _speed_mult() -> float:
	var m: float = _slow_mult if _slow_timer > 0.0 else 1.0
	if _soak_timer > 0.0:
		m *= _soak_mult   # soaked by a flood
	if _poison_timer > 0.0:
		m *= _poison_mult   # poisoned by flowers
	if _sting_timer > 0.0 and _stings > 0:
		m *= pow(_sting_mult, _stings)    # stung by bees (each sting slows you more)
	return m * Powers.speed_multiplier()   # Swift Mint makes you faster


## Shove trick: slide `distance` pixels (negative = left) over `time` seconds, stumbling, no control.
func shove(distance: float, time: float) -> void:
	if state == State.CLIMBING:
		_stop_climbing()
	current_vine = null
	state = State.SHOVED
	planted = false
	_shove_timer = time
	velocity.x = 2.0 * distance / time      # starts fast, slows to a stop after `time`
	_shove_decel = absf(velocity.x) / time
	velocity.y = minf(velocity.y, -140.0)   # a little stumble-hop
	_update_collision_mask()


func _process_shoved(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, _shove_decel * delta)
	velocity.y = minf(velocity.y + _jump_gravity() * fall_gravity_mult * delta, max_fall_speed)
	_shove_timer -= delta
	if _shove_timer <= 0.0:
		state = State.NORMAL


## Flood: soaked, so you move at `multiplier` speed for `seconds` (blue drips show it).
func soak(multiplier: float, seconds: float) -> void:
	_soak_mult = multiplier
	_soak_timer = maxf(_soak_timer, seconds)


func is_soaked() -> bool:
	return _soak_timer > 0.0


## Poison flowers: move at `multiplier` speed for `seconds` (green bubbles show it).
## Touching them again while poisoned starts the timer again from `seconds`.
func poison(multiplier: float, seconds: float) -> void:
	_poison_mult = multiplier
	_poison_timer = seconds


func is_poisoned() -> bool:
	return _poison_timer > 0.0


## Bee sting: each sting slows you to `multiplier` of your speed again (stings stack up to
## `max_stings`), and every new sting starts the `seconds` timer again.
func sting(multiplier: float, seconds: float, max_stings: int = 3) -> void:
	_sting_mult = multiplier
	_stings = mini(_stings + 1, maxi(1, max_stings))
	_sting_timer = seconds


func is_stung() -> bool:
	return _sting_timer > 0.0 and _stings > 0


func sting_count() -> int:
	return _stings if _sting_timer > 0.0 else 0


## Wild Berries: cures poison and bee stings straight away.
func cure() -> void:
	_poison_timer = 0.0
	_sting_timer = 0.0
	_stings = 0
	cured.emit()


## Slow trick: move at `multiplier` speed (0.6 = 60%) for `seconds`.
func apply_slow(multiplier: float, seconds: float) -> void:
	_slow_mult = multiplier
	_slow_timer = seconds


func has_mulberries() -> bool:
	return mulberries > 0


## Empties the basket. Returns how many mulberries were in it.
func empty_basket() -> int:
	var lost: int = mulberries
	mulberries = 0
	_basket_trees.clear()
	_notify_basket()
	return lost


## Mischief "steal" trick: takes the newest berry out of the basket and sends it back to the
## tree it came from. Returns false if the basket was empty.
func steal_mulberry() -> bool:
	if mulberries <= 0:
		return false
	mulberries -= 1
	var tree = _basket_trees.pop_back() if not _basket_trees.is_empty() else null
	if tree != null and is_instance_valid(tree) and tree.has_method("return_berry"):
		tree.return_berry()
	_notify_basket()
	return true


func basket_full() -> bool:
	return mulberries >= basket_size


## A mulberry tree drops a berry into the basket (`from_tree` is remembered, so a stolen
## berry can fly back to it).
func add_mulberry(from_tree = null) -> void:
	if mulberries >= basket_size:
		return
	mulberries += 1
	_basket_trees.append(from_tree)
	_notify_basket()


func _notify_basket() -> void:
	get_tree().call_group("basket_counter", "set_berries", mulberries, basket_size)


# ---------------------------------------------------------------- escaping through the gate
## Locks the controls (used when the gate opens).
func lock_controls() -> void:
	if state == State.CLIMBING:
		_stop_climbing()
	state = State.CUTSCENE
	planted = false
	_auto_walk_speed = 0.0
	velocity = Vector2.ZERO
	_blink_timer = 0.0
	_slow_timer = 0.0
	_poison_timer = 0.0
	_sting_timer = 0.0
	_stings = 0


## Walks to the right on its own (controls stay locked).
func start_auto_walk(speed: float) -> void:
	facing = 1
	_auto_walk_speed = speed


func is_locked() -> bool:
	return state == State.CUTSCENE


## Shows a short word above the wanderer's head that floats up and fades.
func show_popup(text: String) -> void:
	popup.text = text
	popup.position = Vector2(-150, -175)
	popup.modulate.a = 1.0
	if _popup_tween:
		_popup_tween.kill()
	_popup_tween = create_tween()
	_popup_tween.tween_property(popup, "position:y", -215.0, 1.4)
	_popup_tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.6).set_delay(0.8)


# ---------------------------------------------------------------- stones
## Called by a stone on the ground. Returns true if we had room and picked it up.
func try_pick_up_stone() -> bool:
	return stone_thrower.add_stone()


## Aiming is only possible while walking/standing/jumping or hanging on a vine.
func can_aim() -> bool:
	return state == State.NORMAL or state == State.CLIMBING


# ---------------------------------------------------------------- squashing ghosts
## Called by a ghost we just landed on: spring back up (higher if jump is held).
func bounce() -> void:
	velocity.y = -_jump_velocity() * (0.85 if Input.is_action_pressed("jump") else 0.6)
	_coyote = 0.0
	_jump_buffer = 0.0


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
	respawned.emit(pos)


func _update_collision_mask() -> void:
	var m: int = LAYER_WORLD
	if state != State.CLIMBING:
		m |= LAYER_PLATFORMS     # branch platforms only block us when we're not on a vine
	if _blink_timer > 0.0:
		m |= LAYER_HOLE_LID      # while blinking, holes have an invisible lid
	collision_mask = m


# ---------------------------------------------------------------- game feel
## Jumping: a little "hup" and the wanderer stretches upwards for a moment.
func _jumped() -> void:
	Sfx.play("jump", -2.0)
	look.stretch()


## Landing after a fall: a soft thud, a puff of dust and a quick squash (bigger for bigger falls).
func _landed(fall_speed: float) -> void:
	var k: float = clampf((fall_speed - 260.0) / 600.0, 0.0, 1.0)
	Sfx.play("land", lerpf(-9.0, 0.0, k))
	look.land(0.4 + 0.6 * k)
	DustPuff.spawn(get_parent(), global_position, 0.5 + 0.7 * k)


## Shakes the screen for `time` seconds, starting `strength` pixels strong and fading out.
func shake_camera(strength: float, time: float) -> void:
	if strength >= _shake_strength * (_shake_time / maxf(_shake_length, 0.001)):
		_shake_strength = strength
		_shake_length = time
		_shake_time = time


func _update_shake(delta: float) -> void:
	if _shake_time <= 0.0:
		return
	_shake_time = maxf(0.0, _shake_time - delta)
	var s: float = _shake_strength * (_shake_time / _shake_length)
	camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s)) if _shake_time > 0.0 else Vector2.ZERO


# ---------------------------------------------------------------- visuals
## A small red "Stings x2" label above the wanderer's shoulder (only shown while stung).
func _make_sting_label() -> void:
	_sting_label = Label.new()
	_sting_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_sting_label.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.05, 0.95))
	_sting_label.add_theme_constant_override("outline_size", 5)
	_sting_label.add_theme_font_size_override("font_size", 16)
	_sting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sting_label.size = Vector2(120, 22)
	_sting_label.position = Vector2(-60, -138)
	_sting_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sting_label.z_index = 5
	_sting_label.visible = false
	add_child(_sting_label)


func _update_look() -> void:
	look.facing = facing
	var pose: String = "idle"
	if state == State.TRIPPED:
		pose = "tripped"
	elif state == State.SHOVED:
		pose = "stumble"
	elif state == State.CUTSCENE:
		pose = "run" if _auto_walk_speed > 0.0 else "idle"
	elif state == State.CLIMBING:
		pose = "climb_move" if velocity.y != 0.0 else "climb"
	elif not is_on_floor():
		pose = "jump" if velocity.y < 0.0 else "fall"
	elif planted:
		pose = "planted"
	elif absf(velocity.x) > 10.0:
		pose = "run"
	look.pose = pose
	look.slowed = _slow_timer > 0.0
	look.soaked = _soak_timer > 0.0
	look.poisoned = _poison_timer > 0.0
	var stings: int = sting_count()
	look.stings = stings
	_sting_label.visible = stings > 0
	if stings > 0:
		_sting_label.text = "Stings x%d" % stings
	look.speed_ratio = clampf(absf(velocity.x) / run_speed, 0.0, 1.0)
	if _blink_timer > 0.0:
		look.visible = fmod(_blink_timer, 0.16) > 0.08
	else:
		look.visible = true
