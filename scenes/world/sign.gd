@tool
extends Node2D
## A small wooden sign on a post, with a picture on it. Only decoration.
## Pick the picture with `icon`. Warning signs (holes, trunks, poison, bees, crumbling paths,
## floods) get an amber board with a red border and a "!" so they stand out.
## Place this node ON THE GROUND (or on a branch) where the post should stand.

@export_enum("move", "jump", "throw", "climb", "climb_down", "split", "hole", "trunk", "poison",
	"bees", "crumble", "flood", "tree", "gate") var icon: String = "move":
	set(value):
		icon = value
		queue_redraw()

const Circles = preload("res://scripts/circles.gd")
const WARNINGS := ["hole", "trunk", "poison", "bees", "crumble", "flood"]
const POST := Color("5a3b26")
const BOARD := Color("8a6038")
const BOARD_DARK := Color("5e3d22")
const WARN_BOARD := Color("e0a63c")
const WARN_EDGE := Color("b8342c")
const INK := Color("2a1a12")
const LIGHT := Color("f6ead2")
const BW := 64.0      # board width
const BH := 46.0      # board height
const TOP := -96.0    # top of the board


func _draw() -> void:
	var warn: bool = icon in WARNINGS
	# Post
	draw_rect(Rect2(-4, TOP + BH - 4, 8, -TOP - BH + 4), POST)
	Circles.circle(self, Vector2(-8, -2), 6.0, Color("3f8a3a"))
	Circles.circle(self, Vector2(7, -1), 5.0, Color("4f9a3c"))
	# Board
	var r := Rect2(-BW * 0.5, TOP, BW, BH)
	draw_rect(r.grow(2.0), WARN_EDGE if warn else BOARD_DARK)
	draw_rect(r, WARN_BOARD if warn else BOARD)
	if not warn:
		for i in 3:
			draw_line(Vector2(r.position.x + 3, TOP + 12 + i * 12), Vector2(r.end.x - 3, TOP + 12 + i * 12), Color(0, 0, 0, 0.12), 1.0)
	if warn:
		_text(Vector2(r.end.x - 9, TOP + 13), "!", WARN_EDGE, 15)
	var c := Vector2(0, TOP + BH * 0.5)
	match icon:
		"move":
			_key(c + Vector2(-13, 0), "")
			_key(c + Vector2(13, 0), "")
			_arrow(c + Vector2(-13, 0), Vector2.LEFT, INK)
			_arrow(c + Vector2(13, 0), Vector2.RIGHT, INK)
		"jump":
			draw_rect(Rect2(c.x - 26, c.y + 2, 52, 13), LIGHT)
			draw_rect(Rect2(c.x - 26, c.y + 2, 52, 13), INK, false, 1.5)
			_text(c + Vector2(0, 12), "SPACE", INK, 9)
			_arrow(c + Vector2(0, -9), Vector2.UP, INK)
		"throw":
			_key(c + Vector2(-17, 5), "F")
			for k in 5:
				var t: float = k / 4.0
				Circles.circle(self, c + Vector2(-4 + t * 26, -6 - sin(t * PI) * 10 + t * 6), 1.3, INK)
			Circles.circle(self, c + Vector2(23, 2), 4.0, Color("6b6b73"))
		"climb", "climb_down":
			var pts := PackedVector2Array()
			for k in 8:
				pts.append(c + Vector2(-10 + sin(k * 0.9) * 2.0, -18 + k * 5.0))
			draw_polyline(pts, Color("2f7a2f"), 3.0)
			Circles.circle(self, c + Vector2(-6, -8), 3.0, Color("4aa83f"))
			Circles.circle(self, c + Vector2(-14, 6), 3.0, Color("4aa83f"))
			_arrow(c + Vector2(10, 0), Vector2.DOWN if icon == "climb_down" else Vector2.UP, INK)
		"split":
			draw_line(c + Vector2(-20, 14), c + Vector2(-4, 14), INK, 3.0)
			draw_line(c + Vector2(-4, 14), c + Vector2(-4, -8), INK, 3.0)
			draw_line(c + Vector2(-4, 14), c + Vector2(14, 14), INK, 3.0)
			_arrow(c + Vector2(-4, -12), Vector2.UP, INK)
			_arrow(c + Vector2(18, 14), Vector2.RIGHT, INK)
			Circles.circle(self, c + Vector2(10, -10), 6.0, Color("2f7a4a"))   # leaves up top
			Circles.circle(self, c + Vector2(18, -6), 5.0, Color("3f8a4a"))
		"hole":
			draw_rect(Rect2(c.x - 22, c.y + 4, 14, 6), Color("3f8a3a"))
			draw_rect(Rect2(c.x + 8, c.y + 4, 14, 6), Color("3f8a3a"))
			draw_rect(Rect2(c.x - 8, c.y + 4, 16, 14), Color("140a1e"))
			Circles.circle(self, c + Vector2(-3, 13), 1.4, Color("ff3b2f"))
			Circles.circle(self, c + Vector2(3, 13), 1.4, Color("ff3b2f"))
			_arrow(c + Vector2(0, -9), Vector2.DOWN, INK)
		"trunk":
			draw_rect(Rect2(c.x - 20, c.y - 2, 40, 14), Color("5e3b25"))
			Circles.circle(self, c + Vector2(20, 5), 7.0, Color("d3a266"))
			Circles.circle(self, c + Vector2(20, 5), 3.5, Color("a8783f"))
			draw_line(c + Vector2(-22, -6), c + Vector2(-8, -16), INK, 2.0)   # a little "trip" swoosh
			draw_line(c + Vector2(-8, -16), c + Vector2(4, -10), INK, 2.0)
		"poison":
			draw_line(c + Vector2(0, 16), c + Vector2(0, 2), Color("2f6a2f"), 2.0)
			for k in 5:
				var a: float = k * TAU / 5.0
				Circles.circle(self, c + Vector2(0, -2) + Vector2(cos(a), sin(a)) * 6.0, 5.0, Color("9a3fd0"))
			Circles.circle(self, c + Vector2(0, -2), 3.0, Color("f2e05c"))
			for k in 3:
				Circles.circle(self, c + Vector2(-14 + k * 14, -16 + (k % 2) * 4), 2.0, Color("4aa83f"))
		"bees":
			for o: Vector2 in [Vector2(-12, 4), Vector2(10, -6), Vector2(4, 10)]:
				var p: Vector2 = c + o
				Circles.circle(self, p + Vector2(-2, -5), 3.5, Color(1, 1, 1, 0.85))
				Circles.circle(self, p + Vector2(2, -5), 3.5, Color(1, 1, 1, 0.85))
				Circles.circle(self, p, 5.5, Color("f4c430"))
				Circles.circle(self, p + Vector2(-2, 0), 1.8, INK)
				Circles.circle(self, p + Vector2(2, 0), 1.8, INK)
		"crumble":
			for k in 4:
				var x: float = c.x - 24 + k * 13
				var drop: float = 0.0 if k < 2 else (k - 1) * 5.0
				draw_rect(Rect2(x, c.y - 4 + drop, 11, 7), Color("8a5a32"))
			draw_line(c + Vector2(-6, -8), c + Vector2(-2, 2), INK, 1.5)
			draw_line(c + Vector2(-2, 2), c + Vector2(-5, 8), INK, 1.5)
			draw_rect(Rect2(c.x - 26, c.y + 12, 52, 6), Color("140a1e"))
		"flood":
			for row in 2:
				var pts := PackedVector2Array()
				for k in 13:
					pts.append(c + Vector2(-24 + k * 4, -2 + row * 10 + sin(k * 1.2) * 3.0))
				draw_polyline(pts, Color("2f6fd0"), 3.0)
			_arrow(c + Vector2(-16, -14), Vector2.RIGHT, INK)
		"tree":
			draw_rect(Rect2(c.x - 3, c.y, 6, 16), Color("4a2f22"))
			Circles.circle(self, c + Vector2(0, -6), 13.0, Color("22604a"))
			for o: Vector2 in [Vector2(-5, -6), Vector2(5, -9), Vector2(1, -1)]:
				Circles.circle(self, c + o, 2.6, Color("4a1466"))
		"gate":
			draw_rect(Rect2(c.x - 18, c.y - 4, 8, 22), Color("6b6882"))
			draw_rect(Rect2(c.x + 10, c.y - 4, 8, 22), Color("6b6882"))
			draw_arc(c + Vector2(0, -4), 14.0, PI, TAU, 12, Color("6b6882"), 8.0)
			Circles.circle(self, c + Vector2(0, -12), 2.0, Color(1.0, 0.3, 0.25))


func _key(p: Vector2, letter: String) -> void:
	draw_rect(Rect2(p.x - 10, p.y - 10, 20, 20), LIGHT)
	draw_rect(Rect2(p.x - 10, p.y - 10, 20, 20), INK, false, 1.5)
	if letter != "":
		_text(p + Vector2(0, 6), letter, INK, 15)


func _arrow(p: Vector2, dir: Vector2, col: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	draw_line(p - dir * 6.0, p + dir * 3.0, col, 2.5)
	draw_colored_polygon(PackedVector2Array([p + dir * 8.0, p + dir * 1.0 + side * 5.0, p + dir * 1.0 - side * 5.0]), col)


func _text(p: Vector2, text: String, col: Color, size: int) -> void:
	var font: Font = ThemeDB.fallback_font
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, p - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
