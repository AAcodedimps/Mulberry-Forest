@tool
extends "res://scenes/powers/stone_pickup.gd"
## A floating stone that grows back. After it's picked up, it stays gone for `regrow_time`
## seconds, then grows back in the same spot. Used in the clearing near the mulberry tree,
## so the player can never get completely stuck without stones.

# ======================= TUNING =======================
@export var regrow_time: float = 8.0   ## Seconds before a picked-up stone grows back in the same spot.
# ======================================================

var _regrow: float = -1.0   # >= 0 while waiting to grow back


func _after_pop() -> void:
	_regrow = regrow_time
	visible = false


func _physics_process(delta: float) -> void:
	if _regrow >= 0.0:
		_regrow -= delta
		if _regrow <= 0.0:
			_grow_back()
		return
	super(delta)


func _grow_back() -> void:
	_regrow = -1.0
	_pop = -1.0
	modulate.a = 1.0
	visible = true
	set_deferred("monitoring", true)
	scale = Vector2(0.2, 0.2)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
