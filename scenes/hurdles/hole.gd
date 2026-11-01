@tool
extends Node2D
const OnScreen = preload("res://scripts/on_screen.gd")
const Circles = preload("res://scripts/circles.gd")
## A narrow pit in the path, dark inside with two red eyes at the bottom.
## Falling in flashes the screen white, puts the wanderer back at the edge they came from
## and sends GameEvents.deadly_mistake. While the wanderer blinks, an invisible lid covers the hole.
## Place this node at the centre of the gap, level with the top of the ground.

@export var hole_width: float = 96.0:
	set(value):
		hole_width = value
		queue_redraw()
@export var depth: float = 140.0
@export var edge_margin: float = 42.0  ## How far from the hole's lip you reappear.

var _t: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var zone_shape := RectangleShape2D.new()
	zone_shape.size = Vector2(hole_width, 100.0)
	$FallZone/CollisionShape2D.shape = zone_shape
	$FallZone/CollisionShape2D.position = Vector2(0, 110)
	var lid_shape := RectangleShape2D.new()
	lid_shape.size = Vector2(hole_width + 8.0, 8.0)
	$Lid/CollisionShape2D.shape = lid_shape
	$Lid/CollisionShape2D.position = Vector2(0, 4)
	$FallZone.body_entered.connect(_on_fall_zone_body_entered)


func _process(delta: float) -> void:
	_t += delta
	if OnScreen.near(self):   # only redraw when on or near the screen
		queue_redraw()


func _on_fall_zone_body_entered(body) -> void:
	if not body.has_method("respawn_at"):
		return
	if body.is_blinking():
		return
	var came_from_left: bool = body.last_floor_x < global_position.x
	var side: float = -1.0 if came_from_left else 1.0
	var edge := Vector2(global_position.x + side * (hole_width * 0.5 + edge_margin), global_position.y)
	body.call_deferred("respawn_at", edge)
	get_tree().call_group("screen_flash", "flash")
	GameEvents.report_deadly_mistake()


func _draw() -> void:
	var hw: float = hole_width * 0.5
	# Dark pit, lighter near the top
	draw_polygon(
		PackedVector2Array([Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw, depth), Vector2(-hw, depth)]),
		PackedColorArray([Color("2a1840"), Color("2a1840"), Color("05030a"), Color("05030a")]))
	draw_rect(Rect2(-hw, 0, 7, depth), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(hw - 7, 0, 7, depth), Color(0, 0, 0, 0.35))
	# Dangling roots
	var roots: Array = [[-hw + 10, 34.0], [-hw + 26, 20.0], [hw - 18, 40.0], [hw - 34, 16.0]]
	for r: Array in roots:
		var x: float = r[0]
		var length: float = r[1]
		var pts := PackedVector2Array()
		for i in 6:
			var y: float = length * i / 5.0
			pts.append(Vector2(x + sin(y * 0.25 + x) * 2.5, y + 2))
		draw_polyline(pts, Color("5a3b2a"), 2.0)
	# Two glowing red eyes at the bottom (they blink now and then)
	var open: float = 0.15 if fmod(_t, 3.7) < 0.15 else 1.0
	var pulse: float = 0.75 + 0.25 * sin(_t * 2.0)
	for ex: float in [-8.0, 8.0]:
		var c := Vector2(ex, 96)
		Circles.circle(self, c, 11.0, Color(1, 0.1, 0.1, 0.08 * pulse))
		Circles.circle(self, c, 6.0, Color(1, 0.15, 0.1, 0.22 * pulse))
		var pts := PackedVector2Array()
		for i in 14:
			var a: float = TAU * i / 14.0
			pts.append(c + Vector2(cos(a) * 3.2, sin(a) * 2.4 * open))
		draw_colored_polygon(pts, Color("ff3b2f"))
		Circles.circle(self, c, 0.9 * open, Color("ffd8c8"))
	# Mossy lips hanging over the edge
	for i in 4:
		Circles.circle(self, Vector2(-hw + 2 + i * 3, 3 + i * 1.5), 5.0 - i, Color("3f8a3a"))
		Circles.circle(self, Vector2(hw - 2 - i * 3, 3 + i * 1.5), 5.0 - i, Color("3f8a3a"))
