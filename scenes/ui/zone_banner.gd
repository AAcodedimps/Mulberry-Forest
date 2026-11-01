extends CanvasLayer
## Big soft text at the top of the screen with the name of the zone you just walked into.
## It fades in, stays for `show_time` seconds and fades out. The level calls show_zone().

@export var show_time: float = 2.0   ## Seconds the name stays fully visible.
@export var fade_time: float = 0.5   ## Seconds to fade in, and again to fade out.

@onready var _label: Label = $Name
var _tween: Tween


func _ready() -> void:
	add_to_group("zone_banner")
	_label.modulate.a = 0.0


func show_zone(zone_name: String) -> void:
	_label.text = zone_name
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 1.0, fade_time)
	_tween.tween_interval(show_time)
	_tween.tween_property(_label, "modulate:a", 0.0, fade_time)
