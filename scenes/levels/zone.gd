@tool
extends Node2D
## One zone of the forest. Put this node at the zone's LEFT edge, on the ground line (y = 600),
## and put everything that belongs to the zone inside it: move the zone and everything moves.
## When the wanderer walks into the zone, its name shows at the top of the screen (the level
## script does that). `backdrop` adds a little extra scenery behind the zone so each part of
## the forest feels different while keeping the same dusk look.

@export var zone_name: String = "Zone":
	set(value):
		zone_name = value
		queue_redraw()
@export var canopy_name: String = ""       ## Optional: name shown instead when you arrive up in the canopy.
@export var width: float = 1830.0:          ## How wide the zone is (pixels). The next zone should start where this one ends.
	set(value):
		width = value
		_refresh()
@export_enum("none", "hollow", "meadow", "ravine", "stream", "grove") var backdrop: String = "none":
	set(value):
		backdrop = value
		_refresh()
@export var canopy_trunks: bool = false:    ## Draw big dark tree trunks behind the zone (holding up the canopy).
	set(value):
		canopy_trunks = value
		_refresh()

const Circles = preload("res://scripts/circles.gd")
const GROUND_Y := 0.0   # this node sits on the ground line

var _back: Node2D


func _ready() -> void:
	add_to_group("zones")
	_back = Node2D.new()
	_back.name = "Backdrop"
	_back.z_index = -2          # behind everything in the level, in front of the far forest
	_back.show_behind_parent = true
	_back.draw.connect(_draw_backdrop)
	add_child(_back, false, Node.INTERNAL_MODE_FRONT)


func _refresh() -> void:
	if _back != null:
		_back.queue_redraw()
	queue_redraw()


func _draw() -> void:
	# In the editor only: show the zone's extent and name so it's easy to see and move.
	if Engine.is_editor_hint():
		draw_line(Vector2(0, -600), Vector2(0, 120), Color(1, 1, 1, 0.35), 2.0)
		draw_line(Vector2(width, -600), Vector2(width, 120), Color(1, 1, 1, 0.15), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(8, -570), zone_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.7))


func _draw_backdrop() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(width) + zone_name.length() * 31
	if canopy_trunks:
		var x: float = 120.0
		while x < width - 60.0:
			var w: float = rng.randf_range(46.0, 70.0)
			var col := Color(0.09, 0.16, 0.15).lerp(Color(0.12, 0.1, 0.16), rng.randf())
			_back.draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.5, 0), Vector2(x - w * 0.36, -600),
				Vector2(x + w * 0.36, -600), Vector2(x + w * 0.5, 0)]), col)
			_back.draw_line(Vector2(x - w * 0.15, -40), Vector2(x - w * 0.1, -560), col.lightened(0.08), 3.0)
			Circles.circle(_back, Vector2(x, -470 + rng.randf_range(-30, 30)), w * 1.1, col.lightened(0.04))
			x += rng.randf_range(380.0, 520.0)
	match backdrop:
		"hollow":
			# Old hollow stumps and toadstool rings near the path
			for i in int(width / 320.0):
				var x: float = rng.randf_range(80.0, width - 80.0)
				var h: float = rng.randf_range(50.0, 90.0)
				_back.draw_rect(Rect2(x - 22, -h, 44, h), Color(0.18, 0.13, 0.17))
				Circles.circle(_back, Vector2(x, -h * 0.55), 10.0, Color(0.05, 0.03, 0.07))
				for k in 3:
					Circles.circle(_back, Vector2(x - 40 + k * 14, -6), 5.0, Color(0.85, 0.75, 0.6, 0.5))
		"meadow":
			# A meadow: tall grass and flowers of many colours behind the path
			var cols: Array = [Color("f6a6c8"), Color("fff1a0"), Color("b9a6ff"), Color("ffffff"), Color("ff9f7a")]
			# (all the stalks first, then all the flower heads: drawing like shapes together is faster)
			var heads: Array = []
			var x2: float = 0.0
			while x2 < width:
				var h2: float = rng.randf_range(14.0, 34.0)
				_back.draw_line(Vector2(x2, 0), Vector2(x2 + rng.randf_range(-5, 5), -h2), Color(0.25, 0.5, 0.3, 0.9), 2.0)
				if rng.randf() < 0.55:
					heads.append([Vector2(x2, -h2), rng.randf_range(2.5, 4.0), cols[rng.randi() % cols.size()]])
				x2 += rng.randf_range(6.0, 14.0)
			for hd: Array in heads:
				Circles.circle(_back, hd[0], hd[1], hd[2])
		"ravine":
			# Darker: deep shadow over the trees and jagged rocks behind the path
			var dark := Color(0.05, 0.02, 0.1, 0.38)
			var clear := Color(0.05, 0.02, 0.1, 0.0)
			_back.draw_polygon(PackedVector2Array([Vector2(0, -720), Vector2(260, -720), Vector2(260, 0), Vector2(0, 0)]),
				PackedColorArray([clear, dark, dark, clear]))
			_back.draw_polygon(PackedVector2Array([Vector2(260, -720), Vector2(width - 260, -720), Vector2(width - 260, 0), Vector2(260, 0)]),
				PackedColorArray([dark, dark, dark, dark]))
			_back.draw_polygon(PackedVector2Array([Vector2(width - 260, -720), Vector2(width, -720), Vector2(width, 0), Vector2(width - 260, 0)]),
				PackedColorArray([dark, clear, clear, dark]))
			var x3: float = 100.0
			while x3 < width - 100.0:
				var h3: float = rng.randf_range(90.0, 200.0)
				var w3: float = rng.randf_range(90.0, 160.0)
				_back.draw_colored_polygon(PackedVector2Array([Vector2(x3 - w3 * 0.5, 0), Vector2(x3 - w3 * 0.2, -h3),
					Vector2(x3 + w3 * 0.1, -h3 * 0.8), Vector2(x3 + w3 * 0.5, 0)]), Color(0.12, 0.09, 0.15))
				x3 += rng.randf_range(160.0, 260.0)
		"stream":
			# Wet ground: dark pools catching the dusk light, with reeds and mossy stones around them
			var x5: float = 140.0
			while x5 < width - 140.0:
				var pw: float = rng.randf_range(120.0, 220.0)
				var py: float = -rng.randf_range(18.0, 46.0)
				var pool := PackedVector2Array()
				for k in 14:
					var a: float = TAU * k / 14.0
					pool.append(Vector2(x5 + cos(a) * pw * 0.5, py + sin(a) * 7.0))
				_back.draw_colored_polygon(pool, Color(0.14, 0.2, 0.36, 0.75))
				_back.draw_line(Vector2(x5 - pw * 0.3, py - 2.0), Vector2(x5 + pw * 0.1, py - 2.0), Color(0.75, 0.6, 0.75, 0.35), 2.0)
				for k in 5:
					var rx: float = x5 + pw * 0.5 + 6.0 + k * 5.0
					_back.draw_line(Vector2(rx, py + 4.0), Vector2(rx + rng.randf_range(-3, 3), py - rng.randf_range(22.0, 40.0)), Color(0.22, 0.42, 0.28, 0.9), 2.0)
				Circles.circle(_back, Vector2(x5 - pw * 0.5 - 10.0, py + 2.0), 9.0, Color(0.2, 0.18, 0.24))
				x5 += rng.randf_range(300.0, 460.0)
		"grove":
			# A soft green-gold glow over the clearing
			for i in 7:
				var x4: float = width * (i + 0.5) / 7.0
				Circles.circle(_back, Vector2(x4, -150 + rng.randf_range(-60, 40)), rng.randf_range(160, 230), Color(0.8, 1.0, 0.6, 0.05))
			for i in 30:
				Circles.circle(_back, Vector2(rng.randf_range(0, width), rng.randf_range(-500, -60)), rng.randf_range(1.0, 2.2), Color(1.0, 0.95, 0.6, 0.5))
