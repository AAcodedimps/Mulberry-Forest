extends CanvasLayer
## A faint hint at the edge of the screen pointing to the nearest mulberry tree that still has
## berries: a little dim berry with a small chevron, gently pulsing. It only shows while that tree
## is off screen and your basket isn't full, and it's kept quiet on purpose so it doesn't shout.

# ======================= TUNING =======================
@export var strength: float = 0.55       ## How visible it is (0 = invisible, 1 = as bright as the ghost arrows).
@export var edge_margin: float = 30.0    ## How far in from the screen edge it sits (pixels).
# ======================================================

const Circles = preload("res://scripts/circles.gd")
const BERRY := Color(0.62, 0.32, 0.9)

var _draw_node: Control
var _player = null
var _t: float = 0.0


func _ready() -> void:
	layer = 6
	_draw_node = Control.new()
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.draw.connect(_draw_pointer)
	add_child(_draw_node)


func _process(delta: float) -> void:
	_t += delta
	_draw_node.queue_redraw()


func _draw_pointer() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	if _player.basket_full() or _player.is_locked():
		return
	# The nearest tree that still has berries.
	var best = null
	var best_d: float = INF
	for tree in get_tree().get_nodes_in_group("mulberry_trees"):
		if not tree.has_berries():
			continue
		var d: float = tree.global_position.distance_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = tree
	if best == null:
		return
	var rect: Rect2 = _draw_node.get_viewport().get_visible_rect()
	var to_screen: Transform2D = _draw_node.get_viewport().get_canvas_transform()
	var sp: Vector2 = to_screen * (best.global_position + Vector2(0, -120.0 * best.tree_scale))
	if rect.grow(-20.0).has_point(sp):
		return   # you can already see it
	var pos := Vector2(
		clampf(sp.x, rect.position.x + edge_margin, rect.end.x - edge_margin),
		clampf(sp.y, rect.position.y + edge_margin + 60.0, rect.end.y - edge_margin - 90.0))
	var dir: Vector2 = (sp - pos).normalized()
	if dir == Vector2.ZERO:
		return
	var a: float = strength * (0.65 + 0.35 * sin(_t * 2.2))
	var side := Vector2(-dir.y, dir.x)
	# soft glow, a small berry and a little chevron pointing the way
	Circles.circle(_draw_node, pos, 16.0, Color(BERRY.r, BERRY.g, BERRY.b, 0.18 * a))
	Circles.circle(_draw_node, pos, 6.0, Color(BERRY.r, BERRY.g, BERRY.b, a))
	Circles.circle(_draw_node, pos + Vector2(-1.8, -1.8), 1.6, Color(1, 0.9, 1, a))
	var tip: Vector2 = pos + dir * 17.0
	_draw_node.draw_polyline(PackedVector2Array([tip - dir * 6.0 + side * 6.0, tip, tip - dir * 6.0 - side * 6.0]),
		Color(0.85, 0.7, 1.0, a), 2.0)
