@tool
extends Node2D
const Circles = preload("res://scripts/circles.gd")
## The small clearing at the end of the forest: soft moonlight falling through a gap in the
## trees, a pale glow on the moss and a scatter of little white flowers. Only decoration.
## This node's position is the left edge of the clearing, on the ground.

@export var width: float = 850.0:
	set(value):
		width = value
		queue_redraw()

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var shimmer: float = 0.85 + 0.15 * sin(_t * 0.7)
	# Moonlight shafts
	for k in 4:
		var x: float = width * (0.15 + k * 0.22)
		var w: float = 60.0 + k * 12.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w * 0.3, -620), Vector2(x + w * 0.3, -620), Vector2(x + w + 40.0, 0), Vector2(x - w + 40.0, 0)]),
			Color(0.85, 0.95, 1.0, 0.045 * shimmer))
	# Pale glow on the ground
	var glow := PackedVector2Array()
	for i in 24:
		var a: float = TAU * i / 24.0
		glow.append(Vector2(width * 0.5 + cos(a) * width * 0.5, sin(a) * 26.0))
	draw_colored_polygon(glow, Color(0.75, 1.0, 0.8, 0.10 * shimmer))
	# Little white flowers in the moss
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 22:
		var p := Vector2(rng.randf_range(20.0, width - 20.0), -rng.randf_range(2.0, 7.0))
		draw_line(p, p + Vector2(0, 6), Color("4f9a3c"), 1.2)
		for j in 5:
			var a2: float = TAU * j / 5.0 + i
			Circles.circle(self, p + Vector2(cos(a2), sin(a2)) * 2.4, 1.6, Color(0.95, 0.97, 1.0, 0.9))
		Circles.circle(self, p, 1.2, Color("ffe27a"))
