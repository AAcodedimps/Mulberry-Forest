extends RefCounted
## Helps the game run smoothly in a long level: things that animate (vines, holes, pickups,
## hives, the flood, the tree, fireflies...) only need to redraw themselves when they are on or
## near the screen. Their game logic keeps running everywhere; only the drawing is skipped.
##
## Use it in _process / _physics_process instead of a plain queue_redraw():
##     const OnScreen = preload("res://scripts/on_screen.gd")
##     if OnScreen.near(self):
##         queue_redraw()
## `margin` is how far outside the screen (in screen pixels) still counts as "near"; give big
## things that reach far from their position (like the flood or the clearing) a bigger margin.


static func near(item: CanvasItem, margin: float = 900.0) -> bool:
	if Engine.is_editor_hint() or not item.is_inside_tree():
		return true
	var screen: Rect2 = item.get_viewport_rect().grow(margin)
	return screen.has_point(item.get_global_transform_with_canvas().origin)


## The part of the world that's on screen, in `item`'s own local coordinates (grown by `margin`
## screen pixels). Handy for skipping individual things inside one big drawing.
static func visible_local_rect(item: CanvasItem, margin: float = 60.0) -> Rect2:
	var inv: Transform2D = item.get_global_transform_with_canvas().affine_inverse()
	var screen: Rect2 = item.get_viewport_rect().grow(margin)
	var a: Vector2 = inv * screen.position
	var b: Vector2 = inv * screen.end
	return Rect2(a, Vector2.ZERO).expand(b)
