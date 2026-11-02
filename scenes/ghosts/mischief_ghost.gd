extends Node2D
const Circles = preload("res://scripts/circles.gd")
## A mischief ghost: a see-through green sheet ghost with a cheeky grin and a crooked,
## sparkling wand. It rises at the start of the level and floats along the wanderer's
## recorded path (exactly like a killer ghost, but faster). When it reaches the wanderer it
## never hurts them: it plays ONE random trick (shove, slow, or steal one mulberry from the basket,
## which flies back to its tree; with an empty basket it never steals), then vanishes in a puff of
## green sparkles.

# ======================= TUNING =======================
@export var base_speed: float = 288.0                ## Speed of the first mischief ghost (pixels/second). 20% faster than the first killer ghost (240).
@export var speed_increase_per_ghost: float = 0.08   ## Each extra mischief ghost is this much faster than the one before (0.08 = 8%).
@export var shove_distance: float = 160.0            ## Shove trick: how far you're pushed back, in pixels (about 3 metres for the wanderer).
@export var shove_time: float = 0.5                  ## Shove trick: how long you stumble without control (seconds).
@export var slow_multiplier: float = 0.6             ## Slow trick: your speed while slowed (0.6 = 60%).
@export var slow_time: float = 4.0                   ## Slow trick: how long it lasts (seconds).
@export var reach_distance: float = 40.0             ## How close (pixels) it must get to play its trick.
# ======================================================
@export var rise_time: float = 1.0
@export var size_scale: float = 2.1

## Sent when it plays a trick ("shove", "slow" or "steal").
signal trick_played(ghost, trick: String)
## Sent when it disappears (after a trick, or when banished).
signal vanished(ghost)

const BODY := Color(0.3, 0.86, 0.42, 0.7)
const RIM := Color(0.75, 1.0, 0.75, 0.75)
const DARK := Color(0.05, 0.2, 0.08, 0.95)
const TONGUE := Color("ff7a8a")
const WAND := Color("7a4a2a")
const SPARK := Color("fff27a")
const SPARK_GREEN := Color("9dff8a")

var ghost_number: int = 1
var speed: float = 288.0
var recorder = null   # the PathRecorder
var player = null

var _index: int = 0
var _dist: float = 0.0
var _rise: float = 0.0
var _facing: int = 1
var _t: float = 0.0
var _puff: float = -1.0   # -1 = still here; 0..1 = vanishing in sparkles


func _ready() -> void:
	add_to_group("ghosts")
	add_to_group("mischief_ghosts")
	add_to_group("stone_targets")
	modulate.a = 0.0


# ---------------------------------------------------------------- stones
const FloatingText = preload("res://scenes/ui/floating_text.gd")


## Stone target: true if a stone at `point` touches this ghost's body.
func stone_hit_test(point: Vector2) -> bool:
	if _puff >= 0.0:
		return false
	return point.distance_to(global_position + Vector2(0, -50)) <= 46.0


## Stone target: a stone banishes a mischief ghost for good.
func on_stone_hit(_stone) -> void:
	Sfx.play("ghost_hit", 0.0, 1.25)
	FloatingText.spawn(get_parent(), global_position, "Banished!", Color(0.6, 1.0, 0.6))
	GameEvents.report_ghost_beaten(self)
	banish()


## Called by the ghost manager right after the ghost is created.
func setup(path_recorder, target, number: int) -> void:
	recorder = path_recorder
	player = target
	ghost_number = number
	speed = base_speed * pow(1.0 + speed_increase_per_ghost, number - 1)
	global_position = recorder.get_point(0)


# ---------------------------------------------------------------- for stones / shield later
## Gets rid of this mischief ghost for good: it vanishes in a puff of sparkles
## (the ghost manager lowers the counter when it hears `vanished`).
func banish() -> void:
	_vanish()


# ---------------------------------------------------------------- movement
func _physics_process(delta: float) -> void:
	delta *= Powers.world_time_scale()   # Moonpetal slows ghosts down
	_t += delta
	queue_redraw()
	if _puff >= 0.0:
		_puff += delta / 0.6
		if _puff >= 1.0:
			queue_free()
		return
	if recorder == null or player == null:
		return
	if _rise < rise_time:
		_rise += delta
		modulate.a = clampf(_rise / rise_time, 0.0, 1.0)
		return
	_move_along(speed * delta)
	if global_position.distance_to(player.global_position) <= reach_distance:
		if Powers.has_shield():
			# Bark Shield: the mischief ghost is banished instead of playing a trick.
			Powers.shield_block()
			FloatingText.spawn(get_parent(), global_position, "Banished!", Color(0.6, 1.0, 0.6))
			banish()
		else:
			_play_trick()


func _move_along(distance: float) -> void:
	var pts: PackedVector2Array = recorder.points
	if pts.is_empty():
		return
	if _index >= pts.size() - 1:
		_index = pts.size() - 1
		_dist = 0.0
	var remaining: float = distance
	while _index < pts.size() - 1:
		var seg_len: float = pts[_index].distance_to(pts[_index + 1])
		_dist = minf(_dist, seg_len)
		if _dist + remaining < seg_len:
			_dist += remaining
			break
		remaining -= seg_len - _dist
		_index += 1
		_dist = 0.0
	var p: Vector2 = pts[_index]
	if _index < pts.size() - 1:
		p = p.move_toward(pts[_index + 1], _dist)
	var dx: float = p.x - global_position.x
	if absf(dx) > 0.5:
		_facing = 1 if dx > 0.0 else -1
	global_position = p


# ---------------------------------------------------------------- tricks
func _play_trick() -> void:
	var tricks: Array[String] = ["shove", "slow"]
	if player.has_mulberries():
		tricks.append("steal")
	var trick: String = tricks[randi() % tricks.size()]
	match trick:
		"shove":
			player.shove(_came_from_dir() * shove_distance, shove_time)
			player.show_popup("Shoved!")
		"slow":
			player.apply_slow(slow_multiplier, slow_time)
			player.show_popup("Slowed!")
		"steal":
			player.steal_mulberry()   # one berry flies back to the tree it came from
			GameEvents.report_basket_stolen()
			player.show_popup("Mulberry stolen!")
	trick_played.emit(self, trick)
	_vanish()


## Which way (-1 left, +1 right) the wanderer came from, looking back along their path.
func _came_from_dir() -> float:
	var pts: PackedVector2Array = recorder.points
	var here: Vector2 = player.global_position
	for i in range(pts.size() - 1, -1, -1):
		var dx: float = pts[i].x - here.x
		if absf(dx) > 30.0:
			return signf(dx)
	return -float(player.facing)


func _vanish() -> void:
	if _puff >= 0.0:
		return
	_puff = 0.0
	remove_from_group("ghosts")
	remove_from_group("mischief_ghosts")
	remove_from_group("stone_targets")
	vanished.emit(self)


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	var bob: float = sin(_t * 3.4 + ghost_number) * 2.0
	var rise_off: float = (1.0 - clampf(_rise / rise_time, 0.0, 1.0)) * 20.0
	var body_alpha: float = 1.0 if _puff < 0.0 else clampf(1.0 - _puff * 2.5, 0.0, 1.0)
	draw_set_transform(Vector2(0, (bob + rise_off) * size_scale), 0.0,
		Vector2(size_scale * _facing, size_scale))

	if body_alpha > 0.0:
		var a_mul := Color(1, 1, 1, body_alpha)
		Circles.circle(self, Vector2(0, -26), 24.0, Color(0.4, 1.0, 0.5, 0.07) * a_mul)
		# Sheet body with a wavy hem
		var body := PackedVector2Array()
		for i in 17:
			var a: float = PI + PI * i / 16.0
			body.append(Vector2(cos(a) * 14.0, -34.0 + sin(a) * 14.0))
		body.append(Vector2(15, -20))
		for i in 13:
			var x: float = 16.0 - 32.0 * i / 12.0
			body.append(Vector2(x, -6.0 + sin(x * 0.6 + _t * 7.0) * 2.5))
		body.append(Vector2(-15, -20))
		draw_colored_polygon(body, BODY * a_mul)
		var outline := body.duplicate()
		outline.append(body[0])
		draw_polyline(outline, RIM * a_mul, 1.0)
		# Cheeky eyes: happy ^ ^ arcs, one eyebrow raised
		draw_arc(Vector2(3, -35), 2.6, PI * 1.1, PI * 1.9, 8, DARK * a_mul, 1.4)
		draw_arc(Vector2(10, -35), 2.6, PI * 1.1, PI * 1.9, 8, DARK * a_mul, 1.4)
		draw_line(Vector2(7.5, -41.5), Vector2(12.5, -40.0), DARK * a_mul, 1.2)
		# Big grin
		var mouth := PackedVector2Array()
		for i in 11:
			var a: float = PI * 0.05 + PI * 0.9 * i / 10.0
			mouth.append(Vector2(6.5 + cos(a) * 7.0, -31.0 + sin(a) * 5.0))
		draw_colored_polygon(mouth, DARK * a_mul)
		Circles.circle(self, Vector2(7.5, -27.6), 1.8, TONGUE * a_mul)
		# Arm holding a crooked wand with a star tip
		var hand := Vector2(14, -19)
		Circles.circle(self, hand, 4.0, BODY * a_mul)
		var wand := PackedVector2Array([hand, hand + Vector2(4, -4), hand + Vector2(3, -8), hand + Vector2(7, -12), hand + Vector2(6, -16)])
		draw_polyline(wand, WAND * a_mul, 1.6)
		var tip: Vector2 = wand[wand.size() - 1]
		_star(tip, 2.6, SPARK * a_mul)
		# Little sparkles drifting off the wand
		for k in 4:
			var life: float = fmod(_t * 1.3 + k * 0.25, 1.0)
			var sp := tip + Vector2(sin(k * 2.1 + _t) * 5.0 * life + life * 3.0, -life * 10.0)
			_star(sp, 1.3 * (1.0 - life), Color(SPARK_GREEN.r, SPARK_GREEN.g, SPARK_GREEN.b, (1.0 - life) * body_alpha))

	# Puff of green sparkles when vanishing
	if _puff >= 0.0:
		for k in 16:
			var ang: float = k * TAU / 16.0 + k * 0.37
			var r: float = 6.0 + _puff * (18.0 + (k % 3) * 6.0)
			var c := Vector2(cos(ang) * r, -26.0 + sin(ang) * r)
			var col: Color = SPARK if k % 2 == 0 else SPARK_GREEN
			col.a = 1.0 - _puff
			_star(c, 2.2 * (1.0 - _puff * 0.6), col)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _star(c: Vector2, r: float, col: Color) -> void:
	if r <= 0.05:
		return
	draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), col, 0.8)
	draw_line(c + Vector2(0, -r), c + Vector2(0, r), col, 0.8)
	Circles.circle(self, c, r * 0.35, col)
