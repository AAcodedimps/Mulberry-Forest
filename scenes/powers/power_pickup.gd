@tool
extends "res://scenes/powers/floating_pickup.gd"
## A Forest Power you collect by running through it (Swift Mint, Strength Fig, Moonpetal or
## Bark Shield). It uses the shared floating pickup (float, bob, glow, sparkles, pop), and
## switches the power on straight away through the Powers autoload. Its name pops up above
## the wanderer, e.g. "Swift Mint!".

const PowerArt = preload("res://scenes/powers/power_art.gd")

@export_enum("swift_mint", "strength_fig", "moonpetal", "bark_shield") var power_id: String = "swift_mint":
	set(value):
		power_id = value
		glow_color = PowerArt.glow_color(value)
		popup_color = glow_color
		queue_redraw()


func _ready() -> void:
	glow_color = PowerArt.glow_color(power_id)
	popup_color = glow_color.lightened(0.3)
	popup_text = "%s!" % Powers.NAMES.get(power_id, power_id) if not Engine.is_editor_hint() else ""
	super()


func _try_collect(body) -> bool:
	if not body.is_in_group("player"):
		return false
	Powers.activate(power_id)
	return true


func _pickup_sound() -> String:
	return "pickup_power"


func _draw_item() -> void:
	PowerArt.draw(self, power_id, Vector2.ZERO, 1.1, _t)
