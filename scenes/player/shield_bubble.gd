extends Node2D
const Circles = preload("res://scripts/circles.gd")
## Draws the Bark Shield's green bubble around the wanderer while it's up. Every blocked hit
## adds a crack (and a quick flash); when the shield runs out it pops.

const CENTER := Vector2(0, -48)

var _t: float = 0.0
var _flash: float = 0.0
var _pop: float = -1.0
var _was_on: bool = false


func _ready() -> void:
	Powers.shield_blocked.connect(_on_blocked)


func _on_blocked(_hits_left: int) -> void:
	_flash = 0.3


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	var on: bool = Powers.has_shield()
	if _was_on and not on:
		_pop = 0.0
	_was_on = on
	if _pop >= 0.0:
		_pop += delta / 0.35
		if _pop >= 1.0:
			_pop = -1.0
	queue_redraw()


func _draw() -> void:
	if Powers.has_shield():
		var r: float = 66.0 + sin(_t * 3.0) * 2.0
		var fl: float = _flash / 0.3
		Circles.circle(self, CENTER, r, Color(0.4, 1.0, 0.5, 0.10 + 0.15 * fl))
		draw_arc(CENTER, r, 0.0, TAU, 56, Color(0.55, 1.0, 0.6, 0.75 + 0.25 * fl), 3.0)
		draw_arc(CENTER, r - 6.0, _t, _t + 1.2, 16, Color(0.85, 1.0, 0.85, 0.5), 2.0)
		# one crack per blocked hit
		var cracks: int = Powers.shield_hits - Powers.shield_hits_left
		for k in cracks:
			var a: float = 0.6 + k * 2.2
			var p: Vector2 = CENTER + Vector2(cos(a), sin(a)) * r
			var inward: Vector2 = (CENTER - p).normalized()
			var side := Vector2(-inward.y, inward.x)
			draw_polyline(PackedVector2Array([p, p + inward * 9.0 + side * 5.0, p + inward * 16.0 - side * 3.0,
				p + inward * 24.0 + side * 4.0]), Color(0.9, 1.0, 0.9, 0.95), 2.0)
			draw_line(p + inward * 9.0 + side * 5.0, p + inward * 14.0 + side * 12.0, Color(0.9, 1.0, 0.9, 0.8), 1.5)
	elif _pop >= 0.0:
		var pr: float = 66.0 + _pop * 30.0
		draw_arc(CENTER, pr, 0.0, TAU, 56, Color(0.55, 1.0, 0.6, 1.0 - _pop), 3.0)
