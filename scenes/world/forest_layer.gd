@tool
extends Node2D
const Circles = preload("res://scripts/circles.gd")
## One background layer of tree silhouettes (pines and round trees) on a rolling hill.
## The level stacks three of these inside Parallax2D nodes so far trees scroll slower.

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


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layer_seed
	# Trees
	for i in tree_count:
		var x: float = lerpf(x_from, x_to, (i + rng.randf()) / tree_count)
		var h: float = rng.randf_range(min_height, max_height)
		var base: float = hill_y + rng.randf_range(10, 30)
		var col: Color = tree_color.lerp(shade_color, rng.randf() * 0.5)
		var w: float = h * rng.randf_range(0.28, 0.4)
		draw_rect(Rect2(x - w * 0.06, base - h * 0.5, w * 0.12, h * 0.5), col.darkened(0.15))
		if rng.randf() < 0.6:
			var tiers: int = 4
			for t in tiers:
				var ty: float = base - h * 0.25 - t * h * 0.2
				var tw: float = w * (1.0 - t * 0.2)
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - tw * 0.5, ty), Vector2(x + tw * 0.5, ty), Vector2(x, ty - h * 0.38)]), col)
		else:
			var r: float = w * 0.42
			Circles.circle(self, Vector2(x, base - h * 0.62), r, col)
			Circles.circle(self, Vector2(x - r * 0.7, base - h * 0.5), r * 0.75, col)
			Circles.circle(self, Vector2(x + r * 0.7, base - h * 0.52), r * 0.8, col)
	# Rolling hill in front of the tree bases
	var hill := PackedVector2Array()
	var xx: float = x_from
	while xx <= x_to:
		hill.append(Vector2(xx, hill_y + sin(xx * 0.004 + layer_seed) * 12.0))
		xx += 40.0
	hill.append(Vector2(x_to, 900))
	hill.append(Vector2(x_from, 900))
	draw_colored_polygon(hill, shade_color)
