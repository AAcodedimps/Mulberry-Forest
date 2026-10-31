extends Control
## For every ghost that is off screen, draws a pulsing arrow at the edge of the screen
## pointing toward it: red for killer ghosts, green for mischief ghosts.

const MARGIN := 34.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = get_viewport().get_visible_rect()
	var to_screen: Transform2D = get_viewport().get_canvas_transform()
	var pulse: float = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.008)
	for ghost in get_tree().get_nodes_in_group("ghosts"):
		var sp: Vector2 = to_screen * (ghost.global_position + Vector2(0, -45))
		if rect.grow(-4.0).has_point(sp):
			continue  # visible: no arrow needed
		var pos := Vector2(
			clampf(sp.x, rect.position.x + MARGIN, rect.end.x - MARGIN),
			clampf(sp.y, rect.position.y + MARGIN, rect.end.y - MARGIN))
		var dir: Vector2 = (sp - pos).normalized()
		if dir == Vector2.ZERO:
			continue
		var perp := Vector2(-dir.y, dir.x)
		var tri := PackedVector2Array([pos + dir * 18.0, pos - dir * 10.0 + perp * 13.0, pos - dir * 10.0 - perp * 13.0])
		var col := Color(0.35, 1.0, 0.4, pulse) if ghost.is_in_group("mischief_ghosts") else Color(1.0, 0.15, 0.2, pulse)
		draw_colored_polygon(tri, col)
		var outline := tri.duplicate()
		outline.append(tri[0])
		draw_polyline(outline, Color(0.15, 0.0, 0.03, 0.9), 2.0)
