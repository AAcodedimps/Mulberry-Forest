extends RefCounted
const Circles = preload("res://scripts/circles.gd")
## Draws the Forest Power items (and the Wild Berries cure) with plain shapes. Shared by the floating pickups and the
## corner timer icons, so they always look the same. Everything is drawn around `c`, about
## 30 pixels across at size 1.0.
## Use it with:  preload("res://scenes/powers/power_art.gd").draw(canvas, "swift_mint", center, 1.0, time)


static func draw(canvas: CanvasItem, id: String, c: Vector2, s: float, t: float) -> void:
	match id:
		"swift_mint":
			_mint(canvas, c, s, t)
		"strength_fig":
			_fig(canvas, c, s)
		"moonpetal":
			_moonpetal(canvas, c, s, t)
		"bark_shield":
			_shield(canvas, c, s)
		"wild_berries":
			_wild_berries(canvas, c, s, t)


static func glow_color(id: String) -> Color:
	match id:
		"swift_mint":
			return Color(0.55, 1.0, 0.55)
		"strength_fig":
			return Color(1.0, 0.5, 0.7)
		"moonpetal":
			return Color(0.6, 0.85, 1.0)
		"bark_shield":
			return Color(0.6, 1.0, 0.6)
		"wild_berries":
			return Color(1.0, 0.45, 0.45)
	return Color.WHITE


static func _ellipse(canvas: CanvasItem, c: Vector2, r: Vector2, angle: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var a: float = TAU * i / 14.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(angle))
	canvas.draw_colored_polygon(pts, col)


# Swift Mint: a bright green sprig with a little sparkle.
static func _mint(canvas: CanvasItem, c: Vector2, s: float, t: float) -> void:
	canvas.draw_line(c + Vector2(0, 13) * s, c + Vector2(1, -11) * s, Color("2f7d2f"), 2.2 * s)
	for k in 3:
		var y: float = (6.0 - k * 7.0) * s
		var size: float = (1.0 - k * 0.15) * s
		_ellipse(canvas, c + Vector2(-6.0 * size, y), Vector2(7, 3.6) * size, 0.5, Color("5fe35f"))
		_ellipse(canvas, c + Vector2(6.0 * size, y - 2.0 * s), Vector2(7, 3.6) * size, -0.5, Color("7cf77c"))
	var tw: float = 2.0 + 2.0 * absf(sin(t * 4.0))
	var sp := c + Vector2(10, -12) * s
	canvas.draw_line(sp + Vector2(-tw, 0) * s, sp + Vector2(tw, 0) * s, Color(1, 1, 0.8), 1.6 * s)
	canvas.draw_line(sp + Vector2(0, -tw) * s, sp + Vector2(0, tw) * s, Color(1, 1, 0.8), 1.6 * s)


# Strength Fig: a plump purple-red fig.
static func _fig(canvas: CanvasItem, c: Vector2, s: float) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a: float = TAU * i / 20.0
		var r: float = 11.0 if sin(a) > 0.0 else 11.0 - (-sin(a)) * 4.0   # narrower at the top
		pts.append(c + Vector2(cos(a) * r, sin(a) * 12.0 + 2.0) * s)
	canvas.draw_colored_polygon(pts, Color("8a1f4c"))
	_ellipse(canvas, c + Vector2(2, 4) * s, Vector2(7, 7) * s, 0.0, Color("a8325f"))
	Circles.circle(canvas, c + Vector2(-4, -1) * s, 2.6 * s, Color(1, 0.75, 0.85, 0.85))
	canvas.draw_line(c + Vector2(0, -9) * s, c + Vector2(2, -14) * s, Color("5a3b1a"), 2.2 * s)
	_ellipse(canvas, c + Vector2(5, -13) * s, Vector2(4, 2) * s, -0.4, Color("4caf50"))


# Moonpetal: a pale blue glowing flower.
static func _moonpetal(canvas: CanvasItem, c: Vector2, s: float, t: float) -> void:
	Circles.circle(canvas, c, 15.0 * s, Color(0.6, 0.85, 1.0, 0.18))
	for k in 5:
		var a: float = k * TAU / 5.0 + t * 0.3
		_ellipse(canvas, c + Vector2(cos(a), sin(a)) * 7.0 * s, Vector2(7, 4) * s, a, Color("bfe4ff"))
	Circles.circle(canvas, c, 4.0 * s, Color("fff3b0"))
	Circles.circle(canvas, c, 2.0 * s, Color("ffffff"))


# Bark Shield: a round wooden shield with a green rune.
static func _shield(canvas: CanvasItem, c: Vector2, s: float) -> void:
	Circles.circle(canvas, c, 14.0 * s, Color("5a3a1e"))
	Circles.circle(canvas, c, 11.5 * s, Color("8a5a2e"))
	for x: float in [-5.0, 0.0, 5.0]:
		canvas.draw_line(c + Vector2(x, -10.5) * s, c + Vector2(x, 10.5) * s, Color("6e4523"), 1.2 * s)
	Circles.circle(canvas, c, 6.0 * s, Color(0.4, 1.0, 0.5, 0.25))
	var g := Color("7dff8a")
	canvas.draw_line(c + Vector2(0, -6) * s, c + Vector2(0, 6) * s, g, 2.0 * s)
	canvas.draw_line(c + Vector2(0, -2) * s, c + Vector2(4, -6) * s, g, 2.0 * s)
	canvas.draw_line(c + Vector2(0, 2) * s, c + Vector2(-4, -2) * s, g, 2.0 * s)


# Wild Berries: a small cluster of shiny red berries on a little stem with a leaf.
static func _wild_berries(canvas: CanvasItem, c: Vector2, s: float, t: float) -> void:
	canvas.draw_line(c + Vector2(0, -6) * s, c + Vector2(2, -14) * s, Color("5a3b1a"), 2.0 * s)
	_ellipse(canvas, c + Vector2(7, -13) * s, Vector2(5, 2.4) * s, -0.3, Color("4caf50"))
	for o: Vector2 in [Vector2(-5, 1), Vector2(5, 1), Vector2(0, -4), Vector2(0, 6), Vector2(-4, 8), Vector2(4, 8)]:
		Circles.circle(canvas, c + o * s, 4.6 * s, Color("8f1420"))
		Circles.circle(canvas, c + o * s, 3.8 * s, Color("d8283a"))
		Circles.circle(canvas, c + (o + Vector2(-1.4, -1.4)) * s, 1.2 * s, Color(1, 0.85, 0.85, 0.9))
	var tw: float = 1.5 + 1.5 * absf(sin(t * 3.5))
	var sp := c + Vector2(-10, -9) * s
	canvas.draw_line(sp + Vector2(-tw, 0) * s, sp + Vector2(tw, 0) * s, Color(1, 0.9, 0.9), 1.4 * s)
	canvas.draw_line(sp + Vector2(0, -tw) * s, sp + Vector2(0, tw) * s, Color(1, 0.9, 0.9), 1.4 * s)
