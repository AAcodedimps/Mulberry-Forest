extends CanvasLayer
## Ghost information on screen: the "Killer ghosts" and "Mischief ghosts" counters in the
## top-right corner (with a reminder of how to squash killer ghosts while any are chasing),
## and the short message at the top when something happens. The coloured off-screen arrows
## are drawn by Arrows.

@onready var counter: Label = $Counter
@onready var mischief_counter: Label = $MischiefCounter
@onready var tip: Label = $Tip
@onready var message: Label = $Message

var _message_tween: Tween


func _ready() -> void:
	message.modulate.a = 0.0
	tip.visible = false


func set_counts(killer: int, mischief: int) -> void:
	counter.text = "Killer ghosts: %d" % killer
	mischief_counter.text = "Mischief ghosts: %d" % mischief
	tip.visible = killer > 0


func show_message(text: String) -> void:
	message.text = text
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_property(message, "modulate:a", 1.0, 0.3)
	_message_tween.tween_interval(2.6)
	_message_tween.tween_property(message, "modulate:a", 0.0, 0.8)
