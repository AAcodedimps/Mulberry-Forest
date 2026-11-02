extends RefCounted
## The look shared by every menu (title screen, pause menu, controls, end screens): soft rounded
## dusk-coloured buttons with a warm outline when selected, so keyboard and gamepad players can
## always see which button is chosen.
## Use it with:  some_control.theme = preload("res://scenes/ui/ui_style.gd").theme()

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.set_stylebox("normal", "Button", _box(Color(0.16, 0.1, 0.26, 0.82), Color(0.55, 0.45, 0.75, 0.6)))
	_theme.set_stylebox("hover", "Button", _box(Color(0.24, 0.15, 0.36, 0.9), Color(0.85, 0.75, 1.0, 0.9)))
	_theme.set_stylebox("pressed", "Button", _box(Color(0.32, 0.2, 0.44, 0.95), Color(1.0, 0.9, 0.6, 1.0)))
	_theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Color(1.0, 0.88, 0.55, 1.0), 3))
	_theme.set_color("font_color", "Button", Color(0.97, 0.93, 0.86))
	_theme.set_color("font_hover_color", "Button", Color(1, 1, 1))
	_theme.set_color("font_focus_color", "Button", Color(1.0, 0.95, 0.8))
	_theme.set_color("font_pressed_color", "Button", Color(1.0, 0.92, 0.7))
	_theme.set_font_size("font_size", "Button", 28)
	_theme.set_font_size("font_size", "Label", 22)
	return _theme


static func _box(bg: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(18)
	b.content_margin_left = 26
	b.content_margin_right = 26
	b.content_margin_top = 8
	b.content_margin_bottom = 8
	b.shadow_color = Color(0, 0, 0, 0.25)
	b.shadow_size = 4
	return b


## A menu button with the click sound.
static func button(text: String, min_width: float = 280.0) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(min_width, 58)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func(): Sfx.play("ui_click"))
	btn.focus_entered.connect(func(): Sfx.play("ui_click", -10.0, 1.4))
	return btn


## A soft label with an outline.
static func label(text: String, size: int, color: Color = Color(0.97, 0.93, 0.86)) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.16, 0.95))
	l.add_theme_constant_override("outline_size", maxi(4, int(size / 6.0)))
	return l
