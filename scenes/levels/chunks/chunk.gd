@tool
extends Node2D
## One hand-made chunk of the forest (about 1 to 2 screens wide). The forest builder picks
## chunks at random every run and joins them end to end, so:
##  - Put this node at the chunk's LEFT edge, on the ground line (y = 0 here; the builder moves
##    it to y = 600). Everything that belongs to the chunk goes inside it.
##  - The ground must be solid at both ends (start at x = 0 and finish at x = `width`), so
##    chunks always join smoothly. Turn edge shading off on those two ground pieces.
##  - Canopy branches sit at y = -270, vines at y = -276 with length 246 (like the old level).
##  - Marker2D children named "Spot..." are places on the ground where the builder may put a
##    stone, a Forest Power or a Wild Berries cure. "CanopySpot..." markers are the same for
##    the canopy (stones only). Leave plenty: the builder only fills some of them.
##  - Every jump must be possible without powers (holes up to about 140 pixels wide).
## Drop a new chunk scene into this folder and the builder will start using it.

@export var width: float = 1200.0:      ## How wide the chunk is (pixels). 914 pixels is about one screen.
	set(value):
		width = value
		queue_redraw()
@export_enum("easy", "medium", "hard") var difficulty: String = "easy":
	set(value):
		difficulty = value
		queue_redraw()
@export_enum("hollow", "meadow", "ridge", "stream") var theme: String = "hollow":   ## Decides the zone name: Hollow Fork, Bee Meadow, Crumbling Ridge or Flood Stream.
	set(value):
		theme = value
		queue_redraw()
@export_multiline var notes: String = ""   ## What happens in this chunk (just for you).


func _draw() -> void:
	# In the editor only: show the chunk's edges, the ground and canopy lines, and its name.
	if not Engine.is_editor_hint():
		return
	var col: Color = {"easy": Color(0.5, 1, 0.5), "medium": Color(1, 0.85, 0.4), "hard": Color(1, 0.45, 0.4)}.get(difficulty, Color.WHITE)
	draw_line(Vector2(0, -600), Vector2(0, 160), Color(col, 0.6), 2.0)
	draw_line(Vector2(width, -600), Vector2(width, 160), Color(col, 0.6), 2.0)
	draw_line(Vector2(0, 0), Vector2(width, 0), Color(1, 1, 1, 0.12), 1.0)
	draw_dashed_line(Vector2(0, -270), Vector2(width, -270), Color(1, 1, 1, 0.12), 1.0, 8.0)
	draw_string(ThemeDB.fallback_font, Vector2(10, -570), "%s  (%s, %s, %.1f screens)" % [name, difficulty, theme, width / 914.0],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(col, 0.9))
