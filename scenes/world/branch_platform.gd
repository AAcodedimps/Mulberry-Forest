@tool
extends StaticBody2D
## A thick tree branch you can stand on. It's one-way: you can pass up through it from below
## and land on top. This node's position is the centre of the branch's top surface.

@export var width: float = 240.0:
	set(value):
		width = value
		queue_redraw()
@export var thickness: float = 20.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, thickness)
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position = Vector2(0, thickness * 0.5)


func _draw() -> void:
	var hw: float = width * 0.5
	# The limb rising off to the right, toward its tree
	draw_colored_polygon(PackedVector2Array([
		Vector2(hw - 30, 0), Vector2(hw + 80, -260), Vector2(hw + 120, -260), Vector2(hw + 10, thickness)]),
		Color("4a2f22"))
	# Branch body
	draw_rect(Rect2(-hw, 0, width, thickness), Color("6b4430"))
	draw_rect(Rect2(-hw, thickness - 5, width, 5), Color("4a2f22"))
	draw_circle(Vector2(-hw, thickness * 0.5), thickness * 0.5, Color("6b4430"))
	for i in int(width / 30.0):
		var x: float = -hw + 12 + i * 30
		draw_line(Vector2(x, 6), Vector2(x + 14, 8), Color("553524"), 2.0)
	# Moss along the top
	var x2: float = -hw
	while x2 < hw:
		draw_circle(Vector2(x2, 1), 5.0, Color("3f8a3a"))
		x2 += 11.0
	# Leafy clusters
	for c: Vector2 in [Vector2(-hw - 6, -6), Vector2(-hw + 40, -12), Vector2(hw - 10, -14)]:
		draw_circle(c, 18.0, Color("1f6a4f"))
		draw_circle(c + Vector2(10, -6), 13.0, Color("2a8a5e"))
