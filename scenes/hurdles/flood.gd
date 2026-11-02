@tool
extends Node2D
const OnScreen = preload("res://scripts/on_screen.gd")
const Circles = preload("res://scripts/circles.gd")
## A flooding dip: a low stretch of path with a small stream running through it. A nuisance
## hurdle: it never kills you and never makes a ghost.
##  - Every few seconds the stream starts rippling with a rushing sound (the warning).
##  - Then a wave sweeps across the dip and the water stays for a while before draining away.
##  - If you're in the water, it pushes you back the way you came and soaks you (slower for a
##    few seconds, with blue drips). Strength Fig stops the push (you still get soaked).
##  - Moonpetal (Powers.world_time_scale) makes the warning, the wave and the draining slower.
## Place this node on the ground where the dip starts. The ground on both sides should stop at
## the dip's edges; the higher ground there is a safe place to wait.

# ======================= TUNING =======================
@export var wave_interval_min: float = 8.0    ## Shortest time between waves (seconds). The real time is random between min and max.
@export var wave_interval_max: float = 12.0   ## Longest time between waves (seconds).
@export var warning_time: float = 2.0         ## Seconds of rippling and rushing sound before the wave arrives.
@export var wave_time: float = 4.0            ## Seconds the water stays before draining.
@export var push_back_distance: float = 160.0 ## How far the wave pushes you back (pixels; 160 is about 3 metres for the wanderer).
@export var soak_slow: float = 0.7            ## Your speed while soaked (0.7 = 70%).
@export var soak_time: float = 3.0            ## How long you stay soaked (seconds).
# ======================================================
@export var length: float = 500.0:            ## Width of the whole dip, edge to edge (pixels).
	set(value):
		length = value
		queue_redraw()
@export var dip_depth: float = 40.0           ## How much lower the dip is than the path around it.
@export var drain_time: float = 1.2           ## Seconds the water takes to drain away.

enum Phase { CALM, WARNING, FLOODED, DRAINING }

const RAMP := 70.0          # width of each slope down into the dip
const SWEEP_TIME := 0.5     # how long the wave takes to sweep across
const SOIL := Color("4a2f45")
const SOIL_DEEP := Color("1e1226")
const MUD := Color("3a2a30")
const MOSS := Color("3f8a3a")
const MOSS_LIGHT := Color("74c24f")
const WATER := Color(0.25, 0.55, 0.95, 0.72)
const WATER_LIGHT := Color(0.7, 0.88, 1.0, 0.9)

static var _rush_sound: AudioStreamWAV

var _phase: Phase = Phase.CALM
var _timer: float = 0.0
var _next_wave: float = 10.0
var _t: float = 0.0
var _player = null
var _was_in_dip: bool = false
var _entry_side: int = 0          # -1 came in from the left, +1 from the right
var _hit_cooldown: float = 0.0
var _rng := RandomNumberGenerator.new()
var _audio: AudioStreamPlayer2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_rng.randomize()
	_next_wave = _rng.randf_range(wave_interval_min, wave_interval_max)
	var poly := CollisionPolygon2D.new()
	poly.polygon = _surface_points() + PackedVector2Array([Vector2(length, 160), Vector2(0, 160)])
	$Ground.add_child(poly)
	if _rush_sound == null:
		_rush_sound = _make_rush_sound()
	_audio = AudioStreamPlayer2D.new()
	_audio.stream = _rush_sound
	_audio.position = Vector2(length * 0.5, 0)
	_audio.max_distance = 1400.0
	_audio.volume_db = -6.0
	add_child(_audio)


func _exit_tree() -> void:
	if _audio != null:
		_audio.stop()
		_audio.stream = null


func _surface_points() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(RAMP, dip_depth), Vector2(length - RAMP, dip_depth), Vector2(length, 0)])


# ---------------------------------------------------------------- the wave cycle
func _physics_process(delta: float) -> void:
	_t += delta
	if OnScreen.near(self, 1300.0):   # only redraw when on or near the screen
		queue_redraw()
	if Engine.is_editor_hint():
		return
	delta *= Powers.world_time_scale()   # Moonpetal: everything here runs slower
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	_timer += delta
	match _phase:
		Phase.CALM:
			if _timer >= _next_wave:
				_phase = Phase.WARNING
				_timer = 0.0
				_audio.pitch_scale = Powers.world_time_scale()   # the rush lasts as long as the warning
				_audio.play()
		Phase.WARNING:
			if _timer >= warning_time:
				_phase = Phase.FLOODED
				_timer = 0.0
		Phase.FLOODED:
			if _timer >= wave_time:
				_phase = Phase.DRAINING
				_timer = 0.0
		Phase.DRAINING:
			if _timer >= drain_time:
				_phase = Phase.CALM
				_timer = 0.0
				_next_wave = _rng.randf_range(wave_interval_min, wave_interval_max)
	if _player != null:
		_check_player()


func _check_player() -> void:
	var p: Vector2 = _player.global_position - global_position
	var in_dip: bool = p.x > 0.0 and p.x < length and p.y > 4.0
	if in_dip and not _was_in_dip:
		# Remember which side we came in from (that's where the wave pushes us back to).
		_entry_side = -1 if p.x < length * 0.5 else 1
	_was_in_dip = in_dip
	if _phase != Phase.FLOODED or not in_dip or _hit_cooldown > 0.0 or _player.is_locked():
		return
	var front: float = clampf(_timer / SWEEP_TIME, 0.0, 1.0) * length
	if p.x > front:
		return   # the wave hasn't reached us yet
	_hit_cooldown = 1.5
	_player.soak(soak_slow, soak_time)
	if Powers.is_strong():
		_player.show_popup("Soaked!")   # Strength Fig: you stand firm
	else:
		var dir: int = _entry_side if _entry_side != 0 else -int(_player.facing)
		_player.shove(dir * push_back_distance, 0.5)
		_player.show_popup("Swept back!")


## Water level: how far below the path the water surface is (dip_depth = just the stream).
func _water_level() -> float:
	var full: float = -2.0
	var stream: float = dip_depth - 6.0
	match _phase:
		Phase.WARNING:
			return lerpf(stream, stream - 6.0, clampf(_timer / warning_time, 0.0, 1.0))
		Phase.FLOODED:
			return full
		Phase.DRAINING:
			return lerpf(full, stream, clampf(_timer / drain_time, 0.0, 1.0))
	return stream


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	var surface := _surface_points()
	# Soil
	var soil := surface.duplicate()
	soil.append(Vector2(length, 160))
	soil.append(Vector2(0, 160))
	draw_colored_polygon(soil, SOIL)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 100), Vector2(length, 100), Vector2(length, 160), Vector2(0, 160)]), SOIL_DEEP)
	# Muddy bottom
	draw_colored_polygon(PackedVector2Array([Vector2(RAMP - 10, dip_depth - 2), Vector2(length - RAMP + 10, dip_depth - 2),
		Vector2(length - RAMP + 4, dip_depth + 8), Vector2(RAMP - 4, dip_depth + 8)]), MUD)
	# Moss on the slopes and the higher edges
	draw_polyline(PackedVector2Array([surface[0], surface[1]]), MOSS, 8.0)
	draw_polyline(PackedVector2Array([surface[2], surface[3]]), MOSS, 8.0)
	for x: float in [6.0, 20.0, length - 20.0, length - 6.0]:
		Circles.circle(self, Vector2(x, 2), 6.0, MOSS)
	# Reeds at the water's edge
	for x: float in [RAMP + 6.0, RAMP + 14.0, length - RAMP - 10.0, length - RAMP - 2.0]:
		var sway: float = sin(_t * 1.5 + x) * 3.0
		draw_line(Vector2(x, dip_depth), Vector2(x + sway, dip_depth - 30.0), Color("5a8a3a"), 2.0)
		Circles.circle(self, Vector2(x + sway, dip_depth - 30.0), 2.5, Color("7a5a2a"))
	_draw_water()


func _draw_water() -> void:
	var level: float = _water_level()
	var front: float = length
	if _phase == Phase.FLOODED:
		front = clampf(_timer / SWEEP_TIME, 0.0, 1.0) * length
	# The water body follows the dip's shape up to the current level
	var pts := PackedVector2Array()
	var steps: int = 40
	for i in steps + 1:
		var x: float = front * i / steps
		var wave: float = sin(x * 0.05 + _t * 4.0) * (2.5 if level < 0.0 else 1.0)
		pts.append(Vector2(x, level + wave))
	pts.append(Vector2(front, _floor_at(front)))
	for i in range(steps, -1, -1):
		var x2: float = front * i / steps
		pts.append(Vector2(x2, _floor_at(x2)))
	# keep only the part that's actually under water
	var clipped := PackedVector2Array()
	for i in steps + 1:
		var top: Vector2 = pts[i]
		var bottom_y: float = _floor_at(top.x)
		if top.y < bottom_y:
			clipped.append(top)
	if clipped.size() >= 2:
		var poly := PackedVector2Array(clipped)
		for i in range(clipped.size() - 1, -1, -1):
			poly.append(Vector2(clipped[i].x, _floor_at(clipped[i].x)))
		draw_colored_polygon(poly, WATER)
		draw_polyline(clipped, WATER_LIGHT, 2.0)
	# Stream sparkles flowing along
	for k in 6:
		var sx: float = fmod(_t * 60.0 + k * length / 6.0, length - 2.0 * RAMP) + RAMP
		if sx < front:
			draw_line(Vector2(sx, level + 1.0), Vector2(sx + 8.0, level + 1.0), Color(1, 1, 1, 0.6), 1.5)
	# Warning ripples
	if _phase == Phase.WARNING:
		for k in 5:
			var cx: float = RAMP + (length - 2.0 * RAMP) * (k + 0.5) / 5.0
			var r: float = fmod(_t * 25.0 + k * 9.0, 22.0)
			draw_arc(Vector2(cx, level), r, PI, TAU, 16, Color(0.8, 0.95, 1.0, 1.0 - r / 22.0), 1.5)
	# Foam and spray at the front of the sweeping wave
	if _phase == Phase.FLOODED and front < length:
		for k in 6:
			var fy: float = level - 6.0 - fmod(_t * 90.0 + k * 13.0, 30.0)
			Circles.circle(self, Vector2(front - k * 5.0, fy), 3.0, Color(0.9, 0.97, 1.0, 0.8))


## Height of the dip's floor at x (0 at the edges, dip_depth in the middle).
func _floor_at(x: float) -> float:
	if x <= RAMP:
		return dip_depth * x / RAMP
	if x >= length - RAMP:
		return dip_depth * (length - x) / RAMP
	return dip_depth


# ---------------------------------------------------------------- rushing sound
## Builds a 2-second rushing-water sound in code (soft noise that swells and fades).
static func _make_rush_sound() -> AudioStreamWAV:
	var rate: int = 22050
	var length_s: float = 2.0
	var n: int = int(rate * length_s)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var low: float = 0.0
	for i in n:
		var t: float = float(i) / rate
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.12)    # smoothed noise = rushing water
		var swell: float = sin(PI * t / length_s)              # fades in and out
		var sample: float = low * swell * 0.9
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
