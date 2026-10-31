@tool
extends StaticBody2D
## A solid piece of mossy forest path. Its top-left corner is this node's position;
## set `width` to make it longer. Draws soil, a moss carpet, mushrooms and glowing flowers.

@export var width: float = 1000.0:
	set(value):
		width = value
		queue_redraw()
@export var depth: float = 160.0
@export var decor_seed: int = 1:
	set(value):
		decor_seed = value
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, depth)
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position = Vector2(width * 0.5, depth * 0.5)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = decor_seed
	# Soil
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(width, 0), Vector2(width, depth), Vector2(0, depth)]),
		PackedColorArray([Color("4a2f45"), Color("4a2f45"), Color("1e1226"), Color("1e1226")]))
	# Pebbles in the soil
	for i in int(width / 70.0):
		var p := Vector2(rng.randf_range(10, width - 10), rng.randf_range(30, depth - 20))
		draw_circle(p, rng.randf_range(3, 7), Color("5d4566"))
	# Edge shading where the path ends (e.g. at a hole)
	draw_rect(Rect2(0, 0, 5, depth), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(width - 5, 0, 5, depth), Color(0, 0, 0, 0.3))
	# Moss carpet with a bumpy top
	draw_rect(Rect2(0, 0, width, 14), Color("3f8a3a"))
	draw_rect(Rect2(0, 12, width, 4), Color("2c6a2e"))
	var x: float = 6.0
	while x < width - 4.0:
		draw_circle(Vector2(x, 3), rng.randf_range(5, 8), Color("3f8a3a"))
		x += rng.randf_range(10, 16)
	x = 10.0
	while x < width - 6.0:
		draw_circle(Vector2(x, 0), rng.randf_range(2, 3.5), Color("74c24f"))
		x += rng.randf_range(14, 30)
	# Grass blades
	for i in int(width / 18.0):
		var gx: float = rng.randf_range(6, width - 6)
		draw_line(Vector2(gx, 2), Vector2(gx + rng.randf_range(-4, 4), -rng.randf_range(6, 12)), Color("5fae45"), 2.0)
	# Red-capped mushrooms
	for i in int(width / 260.0):
		var mx: float = rng.randf_range(30, width - 30)
		var h: float = rng.randf_range(7, 12)
		draw_rect(Rect2(mx - 1.5, -h, 3, h + 2), Color("f2e3c9"))
		draw_arc(Vector2(mx, -h), 6.0, PI, TAU, 10, Color("e5484d"), 6.0)
		draw_circle(Vector2(mx - 2, -h - 3), 1.0, Color.WHITE)
		draw_circle(Vector2(mx + 2.5, -h - 2), 0.8, Color.WHITE)
	# Glowing blue flowers
	for i in int(width / 180.0):
		var fp := Vector2(rng.randf_range(20, width - 20), -rng.randf_range(4, 9))
		draw_line(fp, Vector2(fp.x, 2), Color("4f9a3c"), 1.5)
		draw_circle(fp, 6.0, Color(0.5, 0.85, 1.0, 0.18))
		draw_circle(fp, 2.5, Color("8fe3ff"))
