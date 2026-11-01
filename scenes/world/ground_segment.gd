@tool
extends StaticBody2D
const Circles = preload("res://scripts/circles.gd")
## A solid piece of mossy forest path. Its top-left corner is this node's position;
## set `width` to make it longer. Draws soil, a moss carpet, mushrooms and glowing flowers.

@export var width: float = 1000.0:
	set(value):
		width = value
		queue_redraw()
@export var depth: float = 160.0
@export var shade_left_edge: bool = true:   ## Darken the left end (turn off where another ground piece continues the path).
	set(value):
		shade_left_edge = value
		queue_redraw()
@export var shade_right_edge: bool = true:  ## Darken the right end (turn off where another ground piece continues the path).
	set(value):
		shade_right_edge = value
		queue_redraw()
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
	# All the random decorations are worked out first (same seed, same order as always, so the
	# path looks exactly the same), then drawn in a few passes of the same kind of shape. Drawing
	# like shapes together lets the graphics card do it in a few batches, which keeps long levels
	# smooth on slower computers.
	var rng := RandomNumberGenerator.new()
	rng.seed = decor_seed
	var pebbles: Array = []
	for i in int(width / 70.0):
		var p := Vector2(rng.randf_range(10, width - 10), rng.randf_range(30, depth - 20))
		pebbles.append([p, rng.randf_range(3, 7)])
	var bumps: Array = []
	var x: float = 6.0
	while x < width - 4.0:
		bumps.append([Vector2(x, 3), rng.randf_range(5, 8), Color("3f8a3a")])
		x += rng.randf_range(10, 16)
	x = 10.0
	while x < width - 6.0:
		bumps.append([Vector2(x, 0), rng.randf_range(2, 3.5), Color("74c24f")])
		x += rng.randf_range(14, 30)
	var blades: Array = []
	for i in int(width / 18.0):
		var gx: float = rng.randf_range(6, width - 6)
		blades.append([Vector2(gx, 2), Vector2(gx + rng.randf_range(-4, 4), -rng.randf_range(6, 12))])
	var mushrooms: Array = []
	for i in int(width / 260.0):
		mushrooms.append([rng.randf_range(30, width - 30), rng.randf_range(7, 12)])
	var flowers: Array = []
	for i in int(width / 180.0):
		flowers.append(Vector2(rng.randf_range(20, width - 20), -rng.randf_range(4, 9)))

	# Pass 1: soil, edge shading and the moss carpet
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(width, 0), Vector2(width, depth), Vector2(0, depth)]),
		PackedColorArray([Color("4a2f45"), Color("4a2f45"), Color("1e1226"), Color("1e1226")]))
	if shade_left_edge:   # edge shading where the path ends (e.g. at a hole)
		draw_rect(Rect2(0, 0, 5, depth), Color(0, 0, 0, 0.3))
	if shade_right_edge:
		draw_rect(Rect2(width - 5, 0, 5, depth), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(0, 0, width, 14), Color("3f8a3a"))
	draw_rect(Rect2(0, 12, width, 4), Color("2c6a2e"))
	# Pass 2: pebbles in the soil and the moss's bumpy top
	for pb: Array in pebbles:
		Circles.circle(self, pb[0], pb[1], Color("5d4566"))
	for b: Array in bumps:
		Circles.circle(self, b[0], b[1], b[2])
	# Pass 3: grass blades and stems
	for bl: Array in blades:
		draw_line(bl[0], bl[1], Color("5fae45"), 2.0)
	for fp: Vector2 in flowers:
		draw_line(fp, Vector2(fp.x, 2), Color("4f9a3c"), 1.5)
	for m: Array in mushrooms:
		draw_rect(Rect2(m[0] - 1.5, -m[1], 3, m[1] + 2), Color("f2e3c9"))
	# Pass 4: red mushroom caps
	for m: Array in mushrooms:
		draw_arc(Vector2(m[0], -m[1]), 6.0, PI, TAU, 10, Color("e5484d"), 6.0)
	# Pass 5: white dots on the caps and the glowing blue flowers
	for m: Array in mushrooms:
		Circles.circle(self, Vector2(m[0] - 2, -m[1] - 3), 1.0, Color.WHITE)
		Circles.circle(self, Vector2(m[0] + 2.5, -m[1] - 2), 0.8, Color.WHITE)
	for fp: Vector2 in flowers:
		Circles.circle(self, fp, 6.0, Color(0.5, 0.85, 1.0, 0.18))
		Circles.circle(self, fp, 2.5, Color("8fe3ff"))
