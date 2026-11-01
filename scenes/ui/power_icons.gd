extends Control
const Circles = preload("res://scripts/circles.gd")
## Bottom-right corner: one icon for every power that's switched on, with a ring around it that
## empties as its 10 seconds run out. Icons flash during their last 2 seconds. Bark Shield also
## shows little dots for the hits it has left.

const PowerArt = preload("res://scenes/powers/power_art.gd")
const SIZE := 30.0     # icon radius
const GAP := 76.0      # space between icons
const MARGIN := Vector2(54, 54)

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var ids: Array = Powers.active_powers()
	for i in ids.size():
		var id: String = ids[i]
		var c := Vector2(size.x - MARGIN.x - i * GAP, size.y - MARGIN.y)
		var left: float = Powers.time_left(id)
		var frac: float = clampf(left / Powers.power_time, 0.0, 1.0)
		var flashing: bool = left <= 2.0 and fmod(_t, 0.3) < 0.15
		var alpha: float = 0.35 if flashing else 1.0
		var glow: Color = PowerArt.glow_color(id)
		Circles.circle(self, c, SIZE, Color(0.08, 0.05, 0.14, 0.75 * alpha))
		draw_arc(c, SIZE + 4.0, 0.0, TAU, 48, Color(1, 1, 1, 0.15 * alpha), 4.0)
		draw_arc(c, SIZE + 4.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 48, Color(glow.r, glow.g, glow.b, alpha), 4.0)
		if not flashing:
			PowerArt.draw(self, id, c, 1.25, _t)
		if id == Powers.BARK_SHIELD:
			for h in Powers.shield_hits:
				var on: bool = h < Powers.shield_hits_left
				Circles.circle(self, c + Vector2((h - (Powers.shield_hits - 1) * 0.5) * 11.0, SIZE + 14.0), 4.0,
					Color(0.5, 1.0, 0.55, alpha) if on else Color(0.3, 0.3, 0.35, 0.6 * alpha))
