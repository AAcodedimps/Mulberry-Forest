extends Node
## GameEvents (global autoload): the game's "noticeboard".
## Hurdles call these functions when the wanderer makes a mistake. Nothing listens yet;
## the ghost system will connect to these signals later.

## Sent when the wanderer makes a serious mistake (e.g. falls into a hole).
signal deadly_mistake
## Sent when the wanderer makes a small mistake (e.g. trips over a trunk).
signal clumsy_mistake
## Sent when a mischief ghost steals the basket (later: mulberries fall back onto the tree).
signal basket_stolen


func report_deadly_mistake() -> void:
	print("[GameEvents] deadly_mistake")
	deadly_mistake.emit()


func report_clumsy_mistake() -> void:
	print("[GameEvents] clumsy_mistake")
	clumsy_mistake.emit()


func report_basket_stolen() -> void:
	print("[GameEvents] basket_stolen")
	basket_stolen.emit()
