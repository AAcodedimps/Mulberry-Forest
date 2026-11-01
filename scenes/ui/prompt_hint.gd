extends CanvasLayer
## A small hint near the bottom of the screen, like "Press F to shake the tree" or "Press E".
## Anything can show one with:  get_tree().call_group("prompt_hint", "show_prompt", self, "Text")
## and remove it with:          get_tree().call_group("prompt_hint", "hide_prompt", self)
## If several things want a hint at once, the newest one is shown.

@onready var box: Control = $Box
@onready var label: Label = $Box/Panel/Label

var _texts := {}       # who asked -> text
var _order: Array = [] # who asked, oldest first


func _ready() -> void:
	add_to_group("prompt_hint")
	box.visible = false


func show_prompt(source: Object, text: String) -> void:
	var key: int = source.get_instance_id()
	_texts[key] = text
	_order.erase(key)
	_order.append(key)
	_refresh()


func hide_prompt(source: Object) -> void:
	var key: int = source.get_instance_id()
	_texts.erase(key)
	_order.erase(key)
	_refresh()


func _refresh() -> void:
	if _order.is_empty():
		box.visible = false
		return
	label.text = _texts[_order.back()]
	box.visible = true
