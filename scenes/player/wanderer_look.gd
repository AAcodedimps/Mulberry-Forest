@tool
extends Node2D
const Circles = preload("res://scripts/circles.gd")
## Draws the wanderer with plain shapes: dark green hooded cloak, pale face and a woven basket
## on the back. The player script sets `facing` and `pose`; this script only handles looks.

const CLOAK := Color("1f5a2e")
const CLOAK_DARK := Color("123d1f")
const CLOAK_LIGHT := Color("2f7a3e")
const FACE := Color("f3e6d3")
const CHEEK := Color("f0b4a8")
const EYE := Color("2a1d1a")
const BASKET := Color("d0954f")
const BASKET_DARK := Color("8f5c2c")
const STRAP := Color("6b4423")
const BOOT := Color("3b2618")
const RIM := Color(0.86, 0.96, 0.7, 0.9)   # light outline so the wanderer stands out at dusk

@export var size_scale: float = 2.1  ## How big the wanderer is drawn (keep the collision box in player.tscn matching).

var facing: int = 1
var pose: String = "idle"
var speed_ratio: float = 0.0
var slowed: bool = false   # true while a mischief ghost's Slow trick is active
var soaked: bool = false   # true while soaked by a flood wave
var poisoned: bool = false # true while poisoned by poison flowers
var stings: int = 0        # how many bee stings (0-3): little red sting marks
var _t: float = 0.0
var _land_k: float = 0.0   # 1 = just landed (squashed), fades to 0
var _jump_k: float = 0.0   # 1 = just jumped (stretched), fades to 0


## Just landed: squash down a little (k = 0..1, how hard the landing was).
func land(k: float) -> void:
	_land_k = maxf(_land_k, k)
	_jump_k = 0.0


## Just jumped: stretch up a little.
func stretch() -> void:
	_jump_k = 1.0
	_land_k = 0.0


func _process(delta: float) -> void:
	_t += delta
	_land_k = move_toward(_land_k, 0.0, delta / 0.16)
	_jump_k = move_toward(_jump_k, 0.0, delta / 0.22)
	scale = Vector2(size_scale if facing >= 0 else -size_scale, size_scale)
	var target_rot: float = 0.0
	if pose == "tripped":
		target_rot = PI * 0.5 * facing
	elif pose == "stumble":
		target_rot = (-0.35 + sin(_t * 30.0) * 0.08) * facing   # lean back, wobbling
	rotation = lerp_angle(rotation, target_rot, minf(1.0, 18.0 * delta))
	queue_redraw()


func _ellipse(c: Vector2, r: Vector2, col: Color, n: int = 18) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


func _draw() -> void:
	# Body bob and squash depending on pose.
	var bob: float = 0.0
	var stride: float = 0.0
	var squash := Vector2.ONE
	match pose:
		"run":
			bob = -absf(sin(_t * 15.0)) * 3.0 * speed_ratio
			stride = sin(_t * 15.0) * 6.0 * speed_ratio
		"idle":
			bob = sin(_t * 2.5) * 0.8
		"planted":
			squash = Vector2(1.1, 0.9)
		"jump":
			squash = Vector2(0.92, 1.08)
		"fall":
			squash = Vector2(1.03, 0.97)
	# Landing squash and jumping stretch (around the feet, so they stay on the ground)
	var land_e: float = _land_k * _land_k
	var jump_e: float = sin(_jump_k * PI * 0.5)
	squash *= Vector2(1.0 + 0.22 * land_e - 0.1 * jump_e, 1.0 - 0.2 * land_e + 0.14 * jump_e)
	# Soft warm glow behind the wanderer
	Circles.circle(self, Vector2(0, -24), 34.0, Color(1.0, 0.9, 0.6, 0.06))
	Circles.circle(self, Vector2(0, -26), 24.0, Color(1.0, 0.92, 0.65, 0.08))

	draw_set_transform(Vector2(0, bob), 0.0, squash)

	# Boots
	var spread: float = 7.0 if pose == "planted" else 4.0
	_ellipse(Vector2(-spread - stride, -3), Vector2(5.5, 3.2), BOOT)
	_ellipse(Vector2(spread + stride, -3), Vector2(5.5, 3.2), BOOT)

	# Cloak (flutters backwards when running or jumping)
	var flutter: float = speed_ratio * 6.0 + (4.0 if pose == "jump" or pose == "fall" else 0.0)
	flutter += sin(_t * 9.0) * 1.5 * speed_ratio
	var cloak := PackedVector2Array([
		Vector2(-9, -31), Vector2(9, -31), Vector2(13, -5),
		Vector2(4, -3), Vector2(-6, -4), Vector2(-15 - flutter, -7),
	])
	draw_colored_polygon(cloak, CLOAK)
	draw_line(Vector2(9, -31), Vector2(13, -5), CLOAK_LIGHT, 2.0)
	draw_line(Vector2(-6, -4), Vector2(13, -5), CLOAK_DARK, 2.0)
	var outline := cloak.duplicate()
	outline.append(cloak[0])
	draw_polyline(outline, RIM, 1.2)

	# Woven basket on the back
	var b := Rect2(-22, -35, 12, 18)
	draw_rect(b, BASKET)
	for i in range(1, 5):
		var y: float = b.position.y + i * 3.6
		draw_line(Vector2(b.position.x, y), Vector2(b.end.x, y), BASKET_DARK, 1.0)
	for i in range(1, 3):
		var x: float = b.position.x + i * 4.0
		draw_line(Vector2(x, b.position.y), Vector2(x, b.end.y), BASKET_DARK, 1.0)
	draw_rect(Rect2(b.position.x - 1, b.position.y - 2, b.size.x + 2, 3), BASKET_DARK)
	draw_rect(b, RIM, false, 1.0)
	draw_line(Vector2(-11, -33), Vector2(3, -24), STRAP, 2.0)

	# Arms reaching up while climbing
	if pose == "climb" or pose == "climb_move":
		var reach: float = sin(_t * 10.0) * 4.0 if pose == "climb_move" else 0.0
		draw_line(Vector2(2, -28), Vector2(7, -46 + reach), CLOAK_LIGHT, 4.0)
		draw_line(Vector2(-2, -28), Vector2(5, -40 - reach), CLOAK_DARK, 4.0)
		Circles.circle(self, Vector2(7, -47 + reach), 2.5, FACE)
		Circles.circle(self, Vector2(5, -41 - reach), 2.5, FACE)

	# Hood with a pointed tip trailing behind
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -45), Vector2(-17 - flutter * 0.5, -40), Vector2(-7, -33)]), CLOAK_DARK)
	Circles.circle(self, Vector2(1, -37), 11.0, CLOAK)
	draw_arc(Vector2(1, -37), 11.0, 0.0, TAU, 28, RIM, 1.2)
	# Face
	_ellipse(Vector2(4.5, -36), Vector2(6.0, 6.5), FACE)
	draw_arc(Vector2(4, -36), 7.5, -PI * 0.55, PI * 0.55, 12, CLOAK_DARK, 2.0)
	if pose == "tripped":
		for ex: float in [4.0, 8.0]:
			draw_line(Vector2(ex - 1.2, -38.2), Vector2(ex + 1.2, -35.8), EYE, 1.0)
			draw_line(Vector2(ex - 1.2, -35.8), Vector2(ex + 1.2, -38.2), EYE, 1.0)
	else:
		var blink: bool = fmod(_t, 3.3) < 0.12
		for ex: float in [4.5, 8.0]:
			if blink:
				draw_line(Vector2(ex - 1.0, -37), Vector2(ex + 1.0, -37), EYE, 1.0)
			else:
				Circles.circle(self, Vector2(ex, -37), 1.1, EYE)
		Circles.circle(self, Vector2(8.5, -33.5), 1.4, CHEEK)

	# Green swirls circling the wanderer while slowed
	if slowed:
		for k in 3:
			var a: float = _t * 3.0 + k * TAU / 3.0
			var c := Vector2(cos(a) * 17.0, -24.0 + sin(a * 1.3) * 16.0)
			draw_arc(c, 3.5, _t * 6.0, _t * 6.0 + 4.0, 10, Color(0.45, 1.0, 0.45, 0.85), 1.2)
			draw_arc(c, 1.8, _t * 6.0 + 1.0, _t * 6.0 + 4.5, 8, Color(0.75, 1.0, 0.6, 0.85), 1.0)

	# Little blue drips falling off the wanderer while soaked
	if soaked:
		for k in 5:
			var fall: float = fmod(_t * 45.0 + k * 11.0, 34.0)
			var d := Vector2(-12.0 + k * 6.0, -40.0 + fall)
			var a: float = 1.0 - fall / 34.0
			Circles.circle(self, d, 1.6, Color(0.45, 0.72, 1.0, 0.9 * a))
			draw_colored_polygon(PackedVector2Array([d + Vector2(-1.4, -0.4), d + Vector2(1.4, -0.4), d + Vector2(0, -3.2)]),
				Color(0.45, 0.72, 1.0, 0.9 * a))

	# Little red sting marks (one per sting): on the cheek, the cloak and the hood
	var marks: Array[Vector2] = [Vector2(7.5, -32.5), Vector2(-3, -18), Vector2(-2, -42)]
	for k in mini(stings, marks.size()):
		var m: Vector2 = marks[k]
		var throb: float = 0.8 + 0.2 * sin(_t * 8.0 + k)
		Circles.circle(self, m, 2.6 * throb, Color(1.0, 0.3, 0.3, 0.35))
		Circles.circle(self, m, 1.5, Color("e0303a"))
		Circles.circle(self, m + Vector2(-0.4, -0.4), 0.5, Color(1, 0.85, 0.85))

	# Little green bubbles floating up around the wanderer while poisoned
	if poisoned:
		for k in 6:
			var rise: float = fmod(_t * 18.0 + k * 9.0, 50.0)
			var bub := Vector2(-14.0 + k * 5.6 + sin(_t * 3.0 + k * 1.7) * 2.5, -6.0 - rise)
			var fade: float = 1.0 - rise / 50.0
			var br: float = 1.4 + (k % 3) * 0.5
			Circles.circle(self, bub, br, Color(0.45, 1.0, 0.35, 0.75 * fade))
			Circles.circle(self, bub + Vector2(-br * 0.35, -br * 0.35), br * 0.4, Color(0.9, 1.0, 0.85, 0.9 * fade))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
