extends CanvasLayer
## The stone counter in the bottom-left corner: a stone icon with "3/5".
## The stone thrower updates it, and it shakes (and flashes red) when you try to
## throw with no stones.

@onready var shaker: Control = $Box/Shaker
@onready var label: Label = $Box/Shaker/Label

var _shake_tween: Tween


func _ready() -> void:
	add_to_group("stone_counter")


func set_stones(count: int, max_count: int) -> void:
	label.text = "%d/%d" % [count, max_count]


func shake() -> void:
	if _shake_tween:
		_shake_tween.kill()
	shaker.position.x = 0.0
	label.modulate = Color(1, 0.45, 0.45)
	_shake_tween = create_tween()
	for x: float in [-10.0, 10.0, -8.0, 8.0, -4.0, 4.0, 0.0]:
		_shake_tween.tween_property(shaker, "position:x", x, 0.04)
	_shake_tween.tween_property(label, "modulate", Color.WHITE, 0.2)
