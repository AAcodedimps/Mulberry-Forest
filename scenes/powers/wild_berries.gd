@tool
extends "res://scenes/powers/floating_pickup.gd"
## Wild Berries: a small cluster of red berries, floating like the Forest Powers. Run through
## them and they cure you straight away: poison from poison flowers and bee stings are gone.
## It's instant, so there's no timer ring in the corner; just a quick "Cured!" above the wanderer.

const PowerArt = preload("res://scenes/powers/power_art.gd")


func _ready() -> void:
	glow_color = PowerArt.glow_color("wild_berries")
	popup_color = Color(1.0, 0.75, 0.75)
	popup_text = "Cured!"
	super()


func _try_collect(body) -> bool:
	if not body.is_in_group("player"):
		return false
	body.cure()
	return true


func _pickup_sound() -> String:
	return "pickup_cure"


func _draw_item() -> void:
	PowerArt.draw(self, "wild_berries", Vector2.ZERO, 1.1, _t)
