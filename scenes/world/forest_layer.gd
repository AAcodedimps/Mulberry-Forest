@tool
extends Node2D
const Circles = preload("res://scripts/circles.gd")
## One background layer of tree silhouettes (pines and round trees) on a rolling hill.
## The level stacks three of these inside Parallax2D nodes so far trees scroll slower.
## Every tree is built from plain triangles. The layer is cut into screen-sized pieces, and each
## piece sends all its triangles to the graphics card as ONE triangle array, so only the pieces
## that are on screen get drawn at all. That keeps long forests smooth on slower graphics cards
## (thousands of separate little draw calls across the whole forest were the slow part).

@export var tree_color: Color = Color("1f5a55"):
	set(value):
		tree_color = value
		queue_redraw()
@export var shade_color: Color = Color("143a3a")
@export var hill_y: float = 520.0      ## Top of this layer's hill.
@export var tree_count: int = 30
@export var min_height: float = 160.0
@export var max_height: float = 320.0
@export var layer_seed: int = 7
@export var x_from: float = -1200.0
@export var x_to: float = 3800.0


const PIECE := 1000.0   # width of one piece of the layer (pixels)

var _pts := PackedVector2Array()
var _cols := PackedColorArray()
var _items: Array[RID] = []    # one canvas item per piece of trees, then one per piece of hill


func _draw() -> void:
	_free_items()
	var buckets := {}            # piece number -> [points, colours]
	var rng := RandomNumberGenerator.new()
	rng.seed = layer_seed
	# Trees (each tree goes into the piece its trunk stands in)
	for i in tree_count:
		var x: float = lerpf(x_from, x_to, (i + rng.randf()) / tree_count)
		var h: float = rng.randf_range(min_height, max_height)
		var base: float = hill_y + rng.randf_range(10, 30)
		var col: Color = tree_color.lerp(shade_color, rng.randf() * 0.5)
		var w: float = h * rng.randf_range(0.28, 0.4)
		_pts = PackedVector2Array()
		_cols = PackedColorArray()
		_rect(Rect2(x - w * 0.06, base - h * 0.5, w * 0.12, h * 0.5), col.darkened(0.15))
		if rng.randf() < 0.6:
			var tiers: int = 4
			for t in tiers:
				var ty: float = base - h * 0.25 - t * h * 0.2
				var tw: float = w * (1.0 - t * 0.2)
				_tri(Vector2(x - tw * 0.5, ty), Vector2(x + tw * 0.5, ty), Vector2(x, ty - h * 0.38), col)
		else:
			var r: float = w * 0.42
			_disc(Vector2(x, base - h * 0.62), r, col)
			_disc(Vector2(x - r * 0.7, base - h * 0.5), r * 0.75, col)
			_disc(Vector2(x + r * 0.7, base - h * 0.52), r * 0.8, col)
		var b: int = int(floorf((x - x_from) / PIECE))
		if not buckets.has(b):
			buckets[b] = [PackedVector2Array(), PackedColorArray()]
		buckets[b][0].append_array(_pts)
		buckets[b][1].append_array(_cols)
	var keys: Array = buckets.keys()
	keys.sort()
	for b in keys:
		var pts: PackedVector2Array = buckets[b][0]
		var idx := PackedInt32Array()
		idx.resize(pts.size())
		for i in pts.size():
			idx[i] = i
		RenderingServer.canvas_item_add_triangle_array(_new_item(), idx, pts, buckets[b][1])
	# Rolling hill in front of the tree bases (after all the trees, also in pieces)
	var a: float = x_from
	while a < x_to:
		var e: float = minf(a + PIECE, x_to)
		var hill := PackedVector2Array()
		var xx: float = a
		while xx < e:
			hill.append(Vector2(xx, _hill_at(xx)))
			xx += 40.0
		hill.append(Vector2(e, _hill_at(e)))
		hill.append(Vector2(e, 900))
		hill.append(Vector2(a, 900))
		RenderingServer.canvas_item_add_polygon(_new_item(), hill, PackedColorArray([shade_color]))
		a = e


func _hill_at(x: float) -> float:
	return hill_y + sin(x * 0.004 + layer_seed) * 12.0


func _new_item() -> RID:
	var item: RID = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(item, get_canvas_item())
	_items.append(item)
	return item


func _free_items() -> void:
	for item in _items:
		RenderingServer.free_rid(item)
	_items.clear()


func _exit_tree() -> void:
	_free_items()


# ---------------------------------------------------------------- batched shapes
func _tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	_pts.append(a)
	_pts.append(b)
	_pts.append(c)
	_cols.append(col)
	_cols.append(col)
	_cols.append(col)


func _rect(r: Rect2, col: Color) -> void:
	_tri(r.position, Vector2(r.end.x, r.position.y), r.end, col)
	_tri(r.position, r.end, Vector2(r.position.x, r.end.y), col)


## A filled circle made of triangles (round tree tops).
func _disc(c: Vector2, r: float, col: Color, sides: int = 20) -> void:
	var prev := c + Vector2(r, 0)
	for i in range(1, sides + 1):
		var a: float = TAU * i / sides
		var p := c + Vector2(cos(a), sin(a)) * r
		_tri(c, prev, p, col)
		prev = p
