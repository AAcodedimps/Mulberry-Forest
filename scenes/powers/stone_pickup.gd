@tool
extends "res://scenes/powers/floating_pickup.gd"
## A floating throwing stone. It uses the shared floating pickup (float, bob, glow, "+1"),
## and only adds what's special about stones: it goes into the wanderer's stone pouch,
## and it's drawn as a little grey stone.


func _try_collect(body) -> bool:
	return body.has_method("try_pick_up_stone") and body.try_pick_up_stone()


func _draw_item() -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a: float = TAU * i / 16.0
		pts.append(Vector2(cos(a) * 13.0, sin(a) * 10.0))
	draw_colored_polygon(pts, Color("74747e"))
	Circles.circle(self, Vector2(-1.5, -1.5), 9.0, Color("9a9aa3"))
	Circles.circle(self, Vector2(-5, -5), 3.0, Color("e0e0e8"))
	draw_arc(Vector2(3, 2), 5.0, 0.2, 1.6, 6, Color("5f5f68"), 1.2)
