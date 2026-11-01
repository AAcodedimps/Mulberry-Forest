@tool
extends Node2D
const Circles = preload("res://scripts/circles.gd")
## Placeholder for the stone gate at the end of the level: two mossy pillars and an arch.
## It has no collision and does nothing yet. This node's position is the base centre.

const STONE_A := Color("7a74b8")
const STONE_B := Color("665fa3")
const MORTAR := Color("3e3a6e")
const MOSS := Color("3f8a3a")

@export var pillar_height: float = 190.0
@export var inner_radius: float = 52.0
@export var outer_radius: float = 92.0


func _draw() -> void:
	var pw: float = outer_radius - inner_radius
	# Pillars made of stacked blocks
	for side: float in [-1.0, 1.0]:
		var x0: float = side * inner_radius if side > 0.0 else -outer_radius
		var y: float = 0.0
		var i: int = 0
		while y > -pillar_height:
			var h: float = minf(38.0, pillar_height + y)
			var r := Rect2(x0, y - h, pw, h)
			draw_rect(r, MORTAR)
			draw_rect(r.grow(-2.0), STONE_A if i % 2 == 0 else STONE_B)
			y -= h
			i += 1
		Circles.circle(self, Vector2(x0 + pw * 0.5, -4), 14.0, MOSS)
	# Arch made of wedge stones
	var c := Vector2(0, -pillar_height)
	var n: int = 7
	for k in n:
		var a0: float = PI + PI * k / n + 0.025
		var a1: float = PI + PI * (k + 1) / n - 0.025
		var poly := PackedVector2Array()
		poly.append(c + Vector2(cos(a0), sin(a0)) * outer_radius)
		poly.append(c + Vector2(cos(a1), sin(a1)) * outer_radius)
		poly.append(c + Vector2(cos(a1), sin(a1)) * inner_radius)
		poly.append(c + Vector2(cos(a0), sin(a0)) * inner_radius)
		draw_colored_polygon(poly, STONE_A if k % 2 == 0 else STONE_B)
	draw_arc(c, outer_radius, PI, TAU, 32, MORTAR, 2.0)
	draw_arc(c, inner_radius, PI, TAU, 32, MORTAR, 2.0)
	# Faint glowing rune on the keystone
	var key := c + Vector2(0, -(inner_radius + outer_radius) * 0.5)
	Circles.circle(self, key, 10.0, Color(0.5, 1.0, 0.9, 0.15))
	draw_line(key + Vector2(0, -6), key + Vector2(0, 6), Color("8ff5de"), 2.0)
	draw_line(key + Vector2(-4, -2), key + Vector2(4, 2), Color("8ff5de"), 2.0)
	# Moss draped over the top
	for k in 6:
		var a: float = PI * 1.25 + k * 0.18
		Circles.circle(self, c + Vector2(cos(a), sin(a)) * outer_radius, 8.0 - k * 0.6, MOSS)
