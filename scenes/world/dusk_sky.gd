@tool
extends Control
const Circles = preload("res://scripts/circles.gd")
## Fills the screen with a dusk sky: indigo at the top fading to rose and amber near the
## horizon, with a pale moon and a few early stars. It sits on a CanvasLayer so it never scrolls.


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var stops: Array = [[0.0, Color("21174a")], [0.4, Color("4b2f6e")], [0.65, Color("b0527a")], [0.82, Color("f08a5d")], [1.0, Color("f7b860")]]
	for i in stops.size() - 1:
		var y0: float = stops[i][0] * h
		var y1: float = stops[i + 1][0] * h
		var c0: Color = stops[i][1]
		var c1: Color = stops[i + 1][1]
		draw_polygon(
			PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1)]),
			PackedColorArray([c0, c0, c1, c1]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 40:
		Circles.circle(self, Vector2(rng.randf() * w, rng.randf() * h * 0.4), rng.randf_range(0.6, 1.5), Color(1, 1, 1, rng.randf_range(0.3, 0.8)))
	var moon := Vector2(w * 0.78, h * 0.2)
	Circles.circle(self, moon, 70.0, Color(1, 0.93, 0.8, 0.08))
	Circles.circle(self, moon, 48.0, Color(1, 0.93, 0.8, 0.12))
	Circles.circle(self, moon, 32.0, Color("fbeccc"))
