extends CanvasLayer
## Everything on screen about Forest Powers: the countdown icons (see power_icons.gd) and the
## soft blue tint over the forest while Moonpetal slows time.

@onready var tint: ColorRect = $Tint


func _ready() -> void:
	tint.modulate.a = 0.0


func _process(delta: float) -> void:
	var target: float = 1.0 if Powers.is_time_slowed() else 0.0
	tint.modulate.a = move_toward(tint.modulate.a, target, delta * 2.0)
