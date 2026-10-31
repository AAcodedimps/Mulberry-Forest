extends CanvasLayer
## The basket counter in the bottom-left corner (above the stones): a little woven basket
## with "Mulberries 1/5". The wanderer updates it whenever the basket changes.

@onready var label: Label = $Box/Shaker/Label
@onready var shaker: Control = $Box/Shaker

var _tween: Tween


func _ready() -> void:
	add_to_group("basket_counter")


func set_berries(count: int, max_count: int) -> void:
	label.text = "Mulberries %d/%d" % [count, max_count]
	label.modulate = Color(0.75, 1.0, 0.75) if count >= max_count else Color.WHITE
	# A little bounce so you notice the change
	if _tween:
		_tween.kill()
	shaker.scale = Vector2(1.12, 1.12)
	_tween = create_tween()
	_tween.tween_property(shaker, "scale", Vector2.ONE, 0.2)
