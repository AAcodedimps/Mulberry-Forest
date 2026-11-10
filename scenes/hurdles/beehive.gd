@tool
extends Node2D
const OnScreen = preload("res://scripts/on_screen.gd")
## A beehive with a small swarm of bees circling it. A nuisance hurdle: it never kills you and
## never makes a ghost.
##  - Get within `chase_distance` of the hive and the swarm chases you for `chase_time` seconds,
##    then flies home (and rests a moment before it can chase again).
##  - Each time the swarm touches you, you're stung: slower for `sting_time` seconds. Stings
##    stack up to `max_stings` (each one slows you more) and every new sting restarts the timer.
##  - Ways past: outrun them (easy with Swift Mint), throw a stone at the hive (the swarm
##    scatters for `scatter_time` seconds and won't chase), Bark Shield blocks stings (each one
##    uses a shield hit), Moonpetal makes the bees fly at half speed, Wild Berries cure all stings.
## Place this node ON THE GROUND where the hive should be. `style` picks a hive hanging from a
## branch (with its little tree), a hive sitting in a flower bush, or (for the canopy) a hive hanging
## from a leafy bough: put that one on the branch you walk along.

# ======================= TUNING =======================
@export var chase_distance: float = 260.0  ## How close you can get to the hive (pixels) before the swarm chases you.
@export var chase_time: float = 4.0        ## How long the swarm chases you before going home (seconds).
@export var bee_speed: float = 250.0       ## How fast the swarm flies (pixels per second; you run at 290).
@export var sting_slow: float = 0.7        ## Your speed after one sting (0.7 = 70%). Two stings = 0.7 x 0.7, and so on.
@export var max_stings: int = 3            ## Stings stack up to this many.
@export var scatter_time: float = 8.0      ## Seconds the swarm stays scattered after a stone hits the hive.
# ======================================================
@export var sting_time: float = 3.0        ## How long stings last (every new sting starts this again).
@export var sting_interval: float = 1.0    ## While the swarm stays on you, it stings again this often (seconds).
@export var rest_time: float = 2.0         ## After flying home, the swarm rests this long before it can chase again.
@export var bee_count: int = 7             ## How many bees are drawn in the swarm.
@export var chase_height_above: float = -1.0 ## How far ABOVE the hive's base you can be and still get chased (-1 = chase_distance + 150). Lower it so a ground hive ignores players up in the canopy.
@export_enum("branch", "bush", "hanging") var style: String = "branch":  ## Hive hanging from its own little tree, sitting in a flower bush, or hanging from a leafy bough (for the canopy).
	set(value):
		style = value
		queue_redraw()

enum State { HOME, CHASE, RETURN, SCATTERED }

const FloatingText = preload("res://scenes/ui/floating_text.gd")
const Circles = preload("res://scripts/circles.gd")
const TOUCH_RADIUS := 42.0      # how close the swarm's middle must be to the wanderer's chest to sting
const HIVE_RADIUS := 24.0       # stone hit size of the hive
const HIVE := Color("d9a441")
const HIVE_DARK := Color("a8742a")
const HIVE_LIGHT := Color("f2cf72")
const BARK := Color("3a2620")
const LEAF := Color("2f6e3a")

var _state: State = State.HOME
var _timer: float = 0.0
var _rest: float = 0.0
var _sting_cd: float = 0.0
var _t: float = 0.0
var _swarm := Vector2.ZERO        # middle of the swarm, relative to this node
var _blend: float = 0.0           # 0 = bees in the swarm, 1 = bees spread out (scattered)
var _bees: Array = []             # per bee: [orbit phase, orbit speed, wobble phase, scatter target]
var _player = null
var _rng := RandomNumberGenerator.new()
var _buzz: AudioStreamPlayer2D   # the swarm's buzzing (loud while chasing, a faint hum at home)


func _ready() -> void:
	_rng.seed = int(position.x) + 11
	_bees.clear()
	for i in bee_count:
		_bees.append([TAU * i / bee_count, _rng.randf_range(2.2, 3.6) * (1.0 if i % 2 == 0 else -1.0),
			_rng.randf() * TAU, Vector2.ZERO])
	_swarm = _hive_pos()
	if Engine.is_editor_hint():
		return
	add_to_group("stone_targets")
	_buzz = AudioStreamPlayer2D.new()
	_buzz.stream = Sfx.bees_stream()
	_buzz.max_distance = 900.0
	_buzz.volume_db = -80.0
	add_child(_buzz)


## Where the hive hangs, relative to this node (which sits on the ground).
func _hive_pos() -> Vector2:
	return Vector2(0, -62) if style == "bush" else Vector2(0, -150)


func _player_chest() -> Vector2:
	return to_local(_player.global_position + Vector2(0, -50))


# ---------------------------------------------------------------- the swarm
func _physics_process(delta: float) -> void:
	_t += delta
	if OnScreen.near(self, 1100.0):   # only redraw when on or near the screen
		queue_redraw()
	if Engine.is_editor_hint():
		_swarm = _hive_pos()
		return
	delta *= Powers.world_time_scale()   # Moonpetal: the bees fly at half speed
	_blend = move_toward(_blend, 1.0 if _state == State.SCATTERED else 0.0, delta * 1.5)
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	_sting_cd = maxf(0.0, _sting_cd - delta)
	var home: Vector2 = _hive_pos()
	var locked: bool = _player.is_locked()
	match _state:
		State.HOME:
			_swarm = _swarm.move_toward(home, bee_speed * delta)
			_rest = maxf(0.0, _rest - delta)
			var d: Vector2 = _player.global_position - global_position
			var above: float = chase_height_above if chase_height_above >= 0.0 else chase_distance + 150.0
			if _rest <= 0.0 and not locked and absf(d.x) < chase_distance and d.y > -above and d.y < 120.0:
				_state = State.CHASE
				_timer = chase_time
		State.CHASE:
			_swarm = _swarm.move_toward(_player_chest(), bee_speed * delta)
			_timer -= delta
			if _timer <= 0.0 or locked:
				_state = State.RETURN
		State.RETURN:
			_swarm = _swarm.move_toward(home, bee_speed * delta)
			if _swarm.distance_to(home) < 4.0:
				_state = State.HOME
				_rest = rest_time
		State.SCATTERED:
			_swarm = _swarm.move_toward(home, bee_speed * delta)
			_timer -= delta
			if _timer <= 0.0:
				_state = State.RETURN
	if _state == State.CHASE and not locked:
		_check_sting()
	_update_buzz(delta)


## The swarm buzzes: loudly while chasing, a faint hum at home, silent when scattered or far away.
func _update_buzz(delta: float) -> void:
	var near: bool = _player.global_position.distance_to(global_position) < 1000.0
	var target: float = -80.0
	if near:
		match _state:
			State.CHASE:
				target = -3.0
			State.RETURN:
				target = -12.0
			State.HOME:
				target = -22.0
	if target > -79.0 and not _buzz.playing:
		_buzz.play(randf() * 0.9)
	_buzz.position = _swarm
	_buzz.volume_db = move_toward(_buzz.volume_db, target, delta * 60.0)
	if _buzz.playing and _buzz.volume_db <= -79.0:
		_buzz.stop()


func _check_sting() -> void:
	if _sting_cd > 0.0 or _swarm.distance_to(_player_chest()) > TOUCH_RADIUS:
		return
	_sting_cd = sting_interval
	if Powers.has_shield():
		if Powers.shield_block():   # Bark Shield blocks the sting (uses one hit)
			FloatingText.spawn(_player.get_parent(), _player.global_position, "Blocked!", Color(0.6, 1.0, 0.65))
		return
	_player.sting(sting_slow, sting_time, max_stings)
	_player.show_popup("Stung!")


# ---------------------------------------------------------------- stones
func stone_hit_test(point: Vector2) -> bool:
	return to_local(point).distance_to(_hive_pos()) < HIVE_RADIUS


func on_stone_hit(_stone) -> void:
	Sfx.play("ghost_hit", -2.0, 1.5)
	_state = State.SCATTERED
	_timer = scatter_time
	for b: Array in _bees:   # every bee flies off to its own spot around the hive
		var a: float = _rng.randf() * TAU
		b[3] = _hive_pos() + Vector2(cos(a), sin(a) * 0.6) * _rng.randf_range(110.0, 190.0)
	FloatingText.spawn(get_parent(), global_position + _hive_pos() + Vector2(0, 100), "Scattered!", Color(1.0, 0.9, 0.4))


## Is the swarm chasing right now? (handy for tests)
func is_chasing() -> bool:
	return _state == State.CHASE


func is_scattered() -> bool:
	return _state == State.SCATTERED


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	var h: Vector2 = _hive_pos()
	if style == "branch":
		_draw_tree(h)
	elif style == "hanging":
		_draw_bough(h)
	else:
		_draw_bush(h)
	_draw_hive(h)
	_draw_bees()


func _draw_tree(h: Vector2) -> void:
	# A slim tree beside the hive, with a branch reaching over it
	var trunk_x: float = -70.0
	draw_colored_polygon(PackedVector2Array([Vector2(trunk_x - 12, 0), Vector2(trunk_x - 7, -210),
		Vector2(trunk_x + 7, -210), Vector2(trunk_x + 12, 0)]), BARK)
	draw_line(Vector2(trunk_x + 4, -180), Vector2(h.x + 40, h.y - 34), BARK, 8.0)
	draw_line(Vector2(h.x, h.y - 32), Vector2(h.x, h.y - 22), Color("5a3b1a"), 2.0)   # little stalk
	for p: Vector2 in [Vector2(trunk_x, -225), Vector2(trunk_x - 26, -205), Vector2(trunk_x + 24, -210),
			Vector2(h.x + 30, h.y - 44), Vector2(h.x + 52, h.y - 36), Vector2(trunk_x + 40, -196)]:
		Circles.circle(self, p, 22.0, LEAF)
	for p: Vector2 in [Vector2(trunk_x - 6, -232), Vector2(h.x + 36, h.y - 50)]:
		Circles.circle(self, p, 12.0, Color("3f8a4a"))


func _draw_bough(h: Vector2) -> void:
	# A leafy bough overhead, with the hive hanging from it on a short stalk
	draw_line(Vector2(h.x - 110, h.y - 52), Vector2(h.x + 90, h.y - 36), BARK, 9.0)
	draw_line(Vector2(h.x, h.y - 40), Vector2(h.x, h.y - 22), Color("5a3b1a"), 2.0)
	for p: Vector2 in [Vector2(h.x - 110, h.y - 60), Vector2(h.x - 70, h.y - 66), Vector2(h.x - 30, h.y - 58),
			Vector2(h.x + 30, h.y - 52), Vector2(h.x + 70, h.y - 50), Vector2(h.x + 100, h.y - 42)]:
		Circles.circle(self, p, 20.0, LEAF)
	for p: Vector2 in [Vector2(h.x - 84, h.y - 74), Vector2(h.x + 52, h.y - 62)]:
		Circles.circle(self, p, 11.0, Color("3f8a4a"))


func _draw_bush(_h: Vector2) -> void:
	# A round flowering bush with the hive sitting in it
	for p: Vector2 in [Vector2(-34, -22), Vector2(34, -22), Vector2(0, -34), Vector2(-18, -14), Vector2(18, -14)]:
		Circles.circle(self, p, 26.0, LEAF)
	for p: Vector2 in [Vector2(-40, -36), Vector2(-22, -48), Vector2(24, -46), Vector2(42, -30), Vector2(-8, -18), Vector2(30, -12)]:
		for k in 5:
			var a: float = k * TAU / 5.0
			Circles.circle(self, p + Vector2(cos(a), sin(a)) * 3.0, 2.6, Color("f6a6c8"))
		Circles.circle(self, p, 1.6, Color("fff1a0"))


func _draw_hive(h: Vector2) -> void:
	# Stacked rings, widest in the middle, with a dark entrance hole
	var rings: Array = [[-20.0, 13.0], [-10.0, 19.0], [0.0, 22.0], [10.0, 19.0], [19.0, 13.0]]
	for r: Array in rings:
		var y: float = r[0]
		var w: float = r[1]
		draw_colored_polygon(PackedVector2Array([Vector2(h.x - w, h.y + y - 6), Vector2(h.x + w, h.y + y - 6),
			Vector2(h.x + w - 2, h.y + y + 5), Vector2(h.x - w + 2, h.y + y + 5)]), HIVE)
		draw_line(Vector2(h.x - w + 2, h.y + y + 5), Vector2(h.x + w - 2, h.y + y + 5), HIVE_DARK, 2.0)
		draw_line(Vector2(h.x - w + 3, h.y + y - 5), Vector2(h.x + w * 0.2, h.y + y - 5), HIVE_LIGHT, 1.5)
	Circles.circle(self, h + Vector2(0, 6), 5.0, Color("3b2414"))
	Circles.circle(self, h, 34.0, Color(1.0, 0.85, 0.3, 0.06))   # warm glow so you notice it


func _draw_bees() -> void:
	var tight: float = 16.0 if _state == State.CHASE else 30.0
	for i in _bees.size():
		var b: Array = _bees[i]
		var ph: float = b[0] + _t * b[1]
		var p: Vector2 = _swarm + Vector2(cos(ph) * tight, sin(ph) * tight * 0.6)
		if _blend > 0.0:   # scattered: each bee drifts around its own spot
			var spot: Vector2 = b[3] + Vector2(sin(_t * 2.0 + b[2]) * 12.0, cos(_t * 2.6 + b[2]) * 8.0)
			p = p.lerp(spot, smoothstep(0.0, 1.0, _blend))
		# buzzing wobble
		p += Vector2(sin(_t * 31.0 + b[2]) * 1.5, cos(_t * 27.0 + b[2] * 1.3) * 1.5)
		var flap: float = absf(sin(_t * 40.0 + i))
		Circles.circle(self, p + Vector2(-1.5, -3.5), 2.4 * (0.6 + 0.4 * flap), Color(0.95, 0.97, 1.0, 0.7))   # wings
		Circles.circle(self, p + Vector2(1.5, -3.5), 2.4 * (0.6 + 0.4 * flap), Color(0.95, 0.97, 1.0, 0.7))
		Circles.circle(self, p, 3.6, Color("f4c430"))                       # yellow body
		Circles.circle(self, p + Vector2(-1.4, 0), 1.3, Color("1a1410"))    # black stripes
		Circles.circle(self, p + Vector2(1.4, 0), 1.3, Color("1a1410"))
