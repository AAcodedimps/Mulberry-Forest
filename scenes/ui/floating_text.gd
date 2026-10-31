extends RefCounted
## Helper for small words that pop up in the world, float upwards and fade (e.g. "Stunned!").
## Use it with:  preload("res://scenes/ui/floating_text.gd").spawn(parent, position, "Text", colour)


static func spawn(parent: Node, world_pos: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_font_size_override("font_size", 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(220, 30)
	label.position = world_pos + Vector2(-110, -150)
	label.z_index = 20
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40.0, 1.2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tween.tween_callback(label.queue_free)
