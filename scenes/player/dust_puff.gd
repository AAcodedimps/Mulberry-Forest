extends Node2D
## A little puff of dust kicked up when the wanderer lands. It spreads out along the ground,
## drifts up a touch and fades away, then removes itself.
## Use it with:  preload("res://scenes/player/dust_puff.gd").spawn(parent, feet_position, strength)

const Circles = preload("res://scripts/circles.gd")
const LIFE := 0.45

var strength: float = 1.0
var _t: float = 0.0


static func spawn(parent: Node, pos: Vector2, puff_strength: float = 1.0) -> void:
	var p = load("res://scenes/player/dust_puff.gd").new()
	p.strength = puff_strength
	p.position = pos
	p.z_index = 3
	parent.add_child(p)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= LIFE:
		queue_free()


func _draw() -> void:
	var k: float = _t / LIFE
	var a: float = (1.0 - k) * 0.75
	for i in 6:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var spread: float = (14.0 + floorf(i * 0.5) * 12.0) * strength
		var p := Vector2(side * spread * (0.4 + k * 1.3), -3.0 - k * 10.0 * (1.0 + floorf(i * 0.5) * 0.3))
		Circles.circle(self, p, (5.5 + floorf(i * 0.5) * 2.0) * (0.7 + k * 0.9) * (0.6 + strength * 0.4), Color(0.86, 0.8, 0.7, a))
