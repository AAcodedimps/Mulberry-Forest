@tool
extends Area2D
## A small grey stone lying on the ground. Walking over it picks it up automatically,
## unless the wanderer already carries the maximum; then it just stays where it is.
## Place this node on the ground surface.

var _t: float = 0.0
var _taken: bool = false


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if Engine.is_editor_hint() or _taken:
		return
	for body in get_overlapping_bodies():
		if body.has_method("try_pick_up_stone") and body.try_pick_up_stone():
			_taken = true
			set_deferred("monitoring", false)
			var tween := create_tween()
			tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.15)
			tween.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
			tween.tween_callback(queue_free)
			return


func _draw() -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a: float = TAU * i / 16.0
		pts.append(Vector2(cos(a) * 11.0, -8.0 + sin(a) * 8.0))
	draw_colored_polygon(pts, Color("7d7d86"))
	draw_circle(Vector2(-1, -9), 7.5, Color("94949c"))
	draw_circle(Vector2(-4, -12), 2.6, Color("d2d2da"))
	# A little twinkle so stones are easy to spot
	var tw: float = maxf(0.0, sin(_t * 2.2 + position.x * 0.05))
	if tw > 0.6:
		var s: float = (tw - 0.6) * 10.0
		var c := Vector2(5, -15)
		draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), Color(1, 1, 0.9, 0.9), 1.5)
		draw_line(c + Vector2(0, -s), c + Vector2(0, s), Color(1, 1, 0.9, 0.9), 1.5)
