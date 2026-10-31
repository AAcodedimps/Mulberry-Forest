@tool
extends Node2D
## A fallen tree trunk lying across the path, nestled in a mossy mound you can walk over.
## If the wanderer runs into it at full speed (see trip_speed in player.gd) they trip and
## GameEvents.clumsy_mistake is sent. Walking slowly or jumping over it is safe.

const BARK := Color("5e3b25")
const BARK_DARK := Color("3f2716")
const WOOD := Color("d3a266")
const RING := Color("a8783f")
const MOSS := Color("3f8a3a")
const MOSS_LIGHT := Color("74c24f")
const MOSS_DARK := Color("2c6a2e")


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	$TripZone.body_entered.connect(_on_trip_zone_body_entered)


func _on_trip_zone_body_entered(body) -> void:
	if body.has_method("try_trip") and body.try_trip():
		GameEvents.report_clumsy_mistake()


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a: float = TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


func _draw() -> void:
	# Mossy mound (matches the collision shape so feet line up)
	var mound := PackedVector2Array([Vector2(-70, 2), Vector2(-26, -40), Vector2(26, -40), Vector2(70, 2)])
	draw_polygon(mound, PackedColorArray([MOSS_DARK, MOSS, MOSS, MOSS_DARK]))
	draw_polyline(PackedVector2Array([Vector2(-70, 0), Vector2(-26, -40), Vector2(26, -40), Vector2(70, 0)]), MOSS_LIGHT, 2.0)
	# The log end (cut face with growth rings)
	var c := Vector2(0, -21)
	_ellipse(c, Vector2(27, 19), BARK)
	_ellipse(c + Vector2(1, 0), Vector2(22, 15), WOOD)
	draw_arc(c + Vector2(1, 0), 10.0, 0.0, TAU, 24, RING, 1.5)
	draw_arc(c + Vector2(1, 0), 5.0, 0.0, TAU, 18, RING, 1.5)
	draw_circle(c + Vector2(1, 0), 1.5, RING)
	draw_line(c + Vector2(4, -3), c + Vector2(17, -9), BARK_DARK, 1.5)
	# Moss cap and little ferns
	for i in 5:
		draw_circle(Vector2(-14 + i * 7, -38 + absf(i - 2) * 1.5), 4.0, MOSS_LIGHT if i % 2 == 0 else MOSS)
	for x: float in [-52.0, 48.0]:
		for j in 3:
			draw_line(Vector2(x, -6), Vector2(x - 6 + j * 6, -18 - j % 2 * 4), MOSS_LIGHT, 2.0)
