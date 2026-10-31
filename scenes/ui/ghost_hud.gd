extends CanvasLayer
## Ghost information on screen: the "Ghosts: N" counter in the top-right corner (with a
## reminder of how to squash them while any are chasing you) and the short message at the
## top when a ghost rises or is squashed. The red off-screen arrows are drawn by Arrows.

@onready var counter: Label = $Counter
@onready var tip: Label = $Tip
@onready var message: Label = $Message

var _message_tween: Tween


func _ready() -> void:
	message.modulate.a = 0.0
	tip.visible = false


func set_ghost_count(n: int) -> void:
	counter.text = "Ghosts: %d" % n
	tip.visible = n > 0


func show_message(text: String) -> void:
	message.text = text
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_property(message, "modulate:a", 1.0, 0.3)
	_message_tween.tween_interval(2.6)
	_message_tween.tween_property(message, "modulate:a", 0.0, 0.8)
