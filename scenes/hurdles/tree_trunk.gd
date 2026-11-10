@tool
extends Node2D
const Circles = preload("res://scripts/circles.gd")
## A fallen tree trunk lying across the path, nestled in a mossy mound you can walk over.
## If the wanderer runs into it at full speed (see trip_speed in player.gd) they trip and
## GameEvents.clumsy_mistake is sent. Walking slowly or jumping over it is safe.
## With Strength Fig on, the wanderer smashes straight through: the trunk breaks into pieces,
## nobody trips and no mischief ghost is made.

const BARK := Color("5e3b25")
const BARK_DARK := Color("3f2716")
const WOOD := Color("d3a266")
const RING := Color("a8783f")
const MOSS := Color("3f8a3a")
const MOSS_LIGHT := Color("74c24f")
const MOSS_DARK := Color("2c6a2e")


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	$TripZone.body_entered.connect(_on_trip_zone_body_entered)


func _on_trip_zone_body_entered(body) -> void:
	if not body.has_method("try_trip"):
		return
	if Powers.is_strong():
		_smash(body)
	elif body.try_trip():
		Sfx.play("trip")
		GameEvents.report_clumsy_mistake()


var _smash_t: float = -1.0   # -1 = whole; 0..1 = pieces flying; >= 1 = broken
var _pieces: Array = []      # [start offset, velocity, spin, size]


## Strength Fig: break the trunk into pieces and let the wanderer through.
func _smash(body) -> void:
	Sfx.play("smash")
	_smash_t = 0.0
	$Body/CollisionPolygon2D.set_deferred("disabled", true)
	$TripZone.set_deferred("monitoring", false)
	var dir: float = signf(body.velocity.x) if body.velocity.x != 0.0 else 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 6:
		_pieces.append([Vector2(rng.randf_range(-22, 22), rng.randf_range(-35, -10)),
			Vector2(dir * rng.randf_range(80, 260), rng.randf_range(-380, -180)),
			rng.randf_range(-9.0, 9.0), rng.randf_range(7.0, 13.0)])
	FloatingText.spawn(get_parent(), global_position + Vector2(0, 40), "Smash!", Color(1.0, 0.6, 0.75))


func _process(delta: float) -> void:
	if _smash_t >= 0.0 and _smash_t < 1.0:
		_smash_t = minf(1.0, _smash_t + delta / 0.9)
		queue_redraw()


const FloatingText = preload("res://scenes/ui/floating_text.gd")


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a: float = TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


func _draw() -> void:
	if _smash_t >= 0.0:
		_draw_broken()
		return
	# Mossy mound (matches the collision shape so feet line up)
	var mound := PackedVector2Array([Vector2(-70, 2), Vector2(-26, -40), Vector2(26, -40), Vector2(70, 2)])
	draw_polygon(mound, PackedColorArray([MOSS_DARK, MOSS, MOSS, MOSS_DARK]))
	draw_polyline(PackedVector2Array([Vector2(-70, 0), Vector2(-26, -40), Vector2(26, -40), Vector2(70, 0)]), MOSS_LIGHT, 2.0)
	# The log end (cut face with growth rings)
	var c := Vector2(0, -21)
	_ellipse(c, Vector2(27, 19), BARK)
	_ellipse(c + Vector2(1, 0), Vector2(22, 15), WOOD)
	draw_arc(c + Vector2(1, 0), 10.0, 0.0, TAU, 24, RING, 1.5)
	draw_arc(c + Vector2(1, 0), 5.0, 0.0, TAU, 18, RING, 1.5)
	Circles.circle(self, c + Vector2(1, 0), 1.5, RING)
	draw_line(c + Vector2(4, -3), c + Vector2(17, -9), BARK_DARK, 1.5)
	# Moss cap and little ferns
	for i in 5:
		Circles.circle(self, Vector2(-14 + i * 7, -38 + absf(i - 2) * 1.5), 4.0, MOSS_LIGHT if i % 2 == 0 else MOSS)
	for x: float in [-52.0, 48.0]:
		for j in 3:
			draw_line(Vector2(x, -6), Vector2(x - 6 + j * 6, -18 - j % 2 * 4), MOSS_LIGHT, 2.0)


func _draw_broken() -> void:
	# A few splinters left on the ground
	for x: float in [-30.0, -8.0, 15.0, 34.0]:
		draw_line(Vector2(x, -1), Vector2(x + 7.0, -5), BARK, 3.0)
	# Pieces flying away and fading
	if _smash_t >= 1.0:
		return
	var t: float = _smash_t * 0.9
	for pc: Array in _pieces:
		var pos: Vector2 = pc[0] + pc[1] * t + Vector2(0, 900.0) * t * t * 0.5
		var size: float = pc[3]
		var a: float = pc[2] * t
		var col := Color(BARK.r, BARK.g, BARK.b, 1.0 - _smash_t)
		var wood := Color(WOOD.r, WOOD.g, WOOD.b, 1.0 - _smash_t)
		var corners := PackedVector2Array()
		for v: Vector2 in [Vector2(-1, -0.6), Vector2(1, -0.6), Vector2(1, 0.6), Vector2(-1, 0.6)]:
			corners.append(pos + (v * size).rotated(a))
		draw_colored_polygon(corners, col)
		Circles.circle(self, pos, size * 0.35, wood)
