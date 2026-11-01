extends RefCounted
## Fast circle drawing.
## Godot's built-in draw_circle() builds a new many-sided shape every time it's called, which is
## slow when hundreds of circles are redrawn every frame (leaves, berries, fireflies, moss...).
## Instead we draw one ready-made round picture, stretched and tinted to the size and colour we
## want. It looks the same but costs about as little as drawing a rectangle.
##
## Use it inside _draw() like this:
##     const Circles = preload("res://scripts/circles.gd")
##     Circles.circle(self, centre, radius, colour)

const SIZE := 128   # pixel size of the round picture (big enough to stay crisp on large circles)

static var _disc: ImageTexture


## The shared white disc picture (made once, the first time a circle is drawn).
static func disc() -> Texture2D:
	if _disc == null:
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		var r: float = SIZE * 0.5
		for y in SIZE:
			for x in SIZE:
				var d: float = Vector2(x + 0.5 - r, y + 0.5 - r).length()
				img.set_pixel(x, y, Color(1, 1, 1, clampf(r - d, 0.0, 1.0)))   # 1-pixel soft edge
		_disc = ImageTexture.create_from_image(img)
	return _disc


## Draws a filled circle on `canvas` (same as canvas.draw_circle(centre, radius, colour)).
static func circle(canvas: CanvasItem, centre: Vector2, radius: float, colour: Color) -> void:
	canvas.draw_texture_rect(disc(), Rect2(centre.x - radius, centre.y - radius, radius * 2.0, radius * 2.0), false, colour)
