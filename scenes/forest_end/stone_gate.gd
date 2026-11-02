@tool
extends Node2D
const OnScreen = preload("res://scripts/on_screen.gd")
const Circles = preload("res://scripts/circles.gd")
## The old stone gate out of the forest: a tall arch covered in vines, with glowing red runes.
## Walk into it:
##  - with fewer mulberries than the basket holds: it's a solid wall and shows
##    "The gate is sealed. It wants 5 mulberries (you have N)."
##  - with a full basket: the wall vanishes, the runes slowly turn from red to green, the vines
##    pull back, and the gate sends `opening`. The level script then walks the wanderer out
##    and shows the win screen.
## Place this node on the ground, in the middle of the arch.

@export var open_time: float = 2.0            ## Seconds the runes and vines take to change when it opens.

## Sent when the gate starts to open.
signal opening

const STONE_A := Color("6b6882")
const STONE_B := Color("5a5770")
const MORTAR := Color("35324a")
const MOSS := Color("3f8a3a")
const RUNE_RED := Color(1.0, 0.18, 0.15)
const RUNE_GREEN := Color(0.35, 1.0, 0.45)
const PILLAR_H := 230.0
const INNER_R := 72.0
const OUTER_R := 122.0

var _t: float = 0.0
var _runes: float = 0.0       # 0 = red, 1 = green
var _vines: float = 1.0       # 1 = covering the gate, 0 = pulled back
var _deny: float = 0.0        # brief rune flicker when the gate refuses you
var _opened: bool = false
var _touching: bool = false
var _player = null


func _physics_process(delta: float) -> void:
	_t += delta
	_deny = maxf(0.0, _deny - delta)
	if OnScreen.near(self):   # only redraw when on or near the screen
		queue_redraw()
	if Engine.is_editor_hint() or _opened:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	# Walking into the gate: the Threshold area sits just in front of the solid wall.
	var touching: bool = $Threshold.overlaps_body(_player) and not _player.is_locked()
	if touching:
		var need: int = _player.basket_size
		var have: int = _player.mulberries
		if have >= need:
			_open()
		elif not _touching:
			_deny = 0.6
			Sfx.play("gate_deny")
			get_tree().call_group("message_hud", "show_message",
				"The gate is sealed. It wants %d mulberries (you have %d)." % [need, have])
	_touching = touching


func _open() -> void:
	_opened = true
	Sfx.play("gate_open")
	$Wall/CollisionShape2D.set_deferred("disabled", true)   # the way through is open
	var tween := create_tween()
	tween.tween_property(self, "_runes", 1.0, open_time)
	tween.parallel().tween_property(self, "_vines", 0.0, open_time * 0.9).set_delay(open_time * 0.1)
	opening.emit()


func _draw() -> void:
	var pw: float = OUTER_R - INNER_R
	var top := Vector2(0, -PILLAR_H)
	# Dark doorway (it glows faintly green as the gate opens)
	var door := PackedVector2Array([Vector2(-INNER_R, 0), Vector2(-INNER_R, -PILLAR_H)])
	for i in range(1, 16):
		var a: float = PI + PI * i / 16.0
		door.append(top + Vector2(cos(a), sin(a)) * INNER_R)
	door.append(Vector2(INNER_R, -PILLAR_H))
	door.append(Vector2(INNER_R, 0))
	draw_colored_polygon(door, Color(0.06, 0.03, 0.1, 0.85).lerp(Color(0.55, 1.0, 0.7, 0.45), _runes))
	# Pillars of stacked blocks
	for side: float in [-1.0, 1.0]:
		var x0: float = INNER_R if side > 0.0 else -OUTER_R
		var y: float = 0.0
		var i: int = 0
		while y > -PILLAR_H:
			var h: float = minf(40.0, PILLAR_H + y)
			var r := Rect2(x0, y - h, pw, h)
			draw_rect(r, MORTAR)
			draw_rect(r.grow(-2.0), STONE_A if i % 2 == 0 else STONE_B)
			y -= h
			i += 1
		Circles.circle(self, Vector2(x0 + pw * 0.5, -4), 16.0, MOSS)
	# Arch of wedge stones
	var n: int = 9
	for k in n:
		var a0: float = PI + PI * k / n + 0.02
		var a1: float = PI + PI * (k + 1) / n - 0.02
		draw_colored_polygon(PackedVector2Array([
			top + Vector2(cos(a0), sin(a0)) * OUTER_R, top + Vector2(cos(a1), sin(a1)) * OUTER_R,
			top + Vector2(cos(a1), sin(a1)) * INNER_R, top + Vector2(cos(a0), sin(a0)) * INNER_R]),
			STONE_A if k % 2 == 0 else STONE_B)
	draw_arc(top, OUTER_R, PI, TAU, 36, MORTAR, 2.0)
	draw_arc(top, INNER_R, PI, TAU, 36, MORTAR, 2.0)
	# Glowing runes: red -> green
	var pulse: float = 0.75 + 0.25 * sin(_t * 2.2)
	if _deny > 0.0:
		pulse = 0.5 + 0.5 * absf(sin(_t * 30.0))
	var rc: Color = RUNE_RED.lerp(RUNE_GREEN, _runes)
	var spots: Array[Vector2] = []
	for side2: float in [-1.0, 1.0]:
		for yy: float in [-55.0, -120.0, -185.0]:
			spots.append(Vector2(side2 * (INNER_R + pw * 0.5), yy))
	spots.append(top + Vector2(0, -(INNER_R + OUTER_R) * 0.5))
	for j in spots.size():
		_rune(spots[j], j, rc, pulse)
	# Vines draped over the arch (they pull back up as the gate opens)
	var strands: Array = [[-110.0, 150.0], [-82.0, 210.0], [-45.0, 175.0], [-12.0, 230.0], [20.0, 190.0],
		[52.0, 220.0], [88.0, 160.0], [112.0, 120.0]]
	for s: Array in strands:
		var sx: float = s[0]
		var in_door: bool = absf(sx) < INNER_R
		var amount: float = _vines if in_door else lerpf(0.35, 1.0, _vines)
		var length: float = float(s[1]) * amount
		var start_y: float = -PILLAR_H - sqrt(maxf(0.0, OUTER_R * OUTER_R - sx * sx)) + 6.0
		var pts := PackedVector2Array()
		var steps: int = maxi(2, int(length / 10.0))
		for m in steps + 1:
			var yv: float = start_y + length * m / steps
			pts.append(Vector2(sx + sin(yv * 0.06 + _t * 1.3 + sx) * 4.0, yv))
		draw_polyline(pts, Color("1f5a26"), 4.0)
		draw_polyline(pts, Color("3f9a3c"), 2.0)
		for m in range(1, pts.size(), 2):
			var lp: Vector2 = pts[m] + Vector2(6.0 if m % 4 == 1 else -6.0, 0)
			Circles.circle(self, lp, 4.5, Color("4aa83f"))


func _rune(c: Vector2, kind: int, col: Color, pulse: float) -> void:
	Circles.circle(self, c, 13.0, Color(col.r, col.g, col.b, 0.15 * pulse))
	var w: Color = Color(col.r, col.g, col.b, 0.6 + 0.4 * pulse)
	match kind % 4:
		0:
			draw_line(c + Vector2(0, -8), c + Vector2(0, 8), w, 2.0)
			draw_line(c + Vector2(0, -2), c + Vector2(6, -7), w, 2.0)
		1:
			draw_arc(c, 6.0, 0.3, PI + 0.3, 8, w, 2.0)
			draw_line(c + Vector2(-6, 2), c + Vector2(6, 8), w, 2.0)
		2:
			draw_line(c + Vector2(-6, -7), c + Vector2(6, 7), w, 2.0)
			draw_line(c + Vector2(6, -7), c + Vector2(-6, 7), w, 2.0)
			draw_line(c + Vector2(-7, 0), c + Vector2(7, 0), w, 2.0)
		3:
			draw_polyline(PackedVector2Array([c + Vector2(-6, 7), c + Vector2(0, -8), c + Vector2(6, 7), c + Vector2(-6, 7)]), w, 2.0)
