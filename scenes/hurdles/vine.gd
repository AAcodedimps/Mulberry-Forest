@tool
extends Node2D
const Circles = preload("res://scripts/circles.gd")
## A climbable vine hanging down from its top point (this node's position) by `length` pixels.
## It tells the wanderer when they start or stop touching it; the player script does the climbing.

@export var length: float = 176.0:
	set(value):
		length = value
		queue_redraw()

var _t: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, length)
	$ClimbZone/CollisionShape2D.shape = shape
	$ClimbZone/CollisionShape2D.position = Vector2(0, length * 0.5)
	$ClimbZone.body_entered.connect(_on_body_entered)
	$ClimbZone.body_exited.connect(_on_body_exited)


func get_top_y() -> float:
	return global_position.y


func get_bottom_y() -> float:
	return global_position.y + length


func _on_body_entered(body) -> void:
	if body.has_method("enter_vine"):
		body.enter_vine(self)


func _on_body_exited(body) -> void:
	if body.has_method("leave_vine"):
		body.leave_vine(self)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _sway(y: float) -> float:
	return sin(y * 0.045 + _t * 1.2) * 3.0 * (y / maxf(length, 1.0))


func _draw() -> void:
	var pts := PackedVector2Array()
	var steps: int = int(length / 8.0) + 1
	for i in steps + 1:
		var y: float = minf(i * 8.0, length)
		pts.append(Vector2(_sway(y), y))
	draw_polyline(pts, Color("1f5a26"), 6.0)
	draw_polyline(pts, Color("3f9a3c"), 3.0)
	# Leaves on alternating sides
	var side: float = 1.0
	var y2: float = 14.0
	while y2 < length - 4.0:
		var p := Vector2(_sway(y2), y2)
		draw_set_transform(p + Vector2(side * 6.0, 0), side * 0.6, Vector2.ONE)
		var leaf := PackedVector2Array()
		for i in 12:
			var a: float = TAU * i / 12.0
			leaf.append(Vector2(cos(a) * 7.0, sin(a) * 3.5))
		draw_colored_polygon(leaf, Color("5cc04a") if side > 0.0 else Color("4aa83f"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		side = -side
		y2 += 16.0
	# A small glowing flower at the tip
	var tip := Vector2(_sway(length), length)
	Circles.circle(self, tip, 7.0, Color(0.8, 0.5, 1.0, 0.2))
	Circles.circle(self, tip, 3.5, Color("d08cff"))
	Circles.circle(self, tip, 1.4, Color("fff2a8"))
