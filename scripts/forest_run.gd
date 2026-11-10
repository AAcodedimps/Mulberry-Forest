extends Node
## ForestRun (global autoload): remembers which random forest is being played.
## Every forest has a number ("Forest #4821"). The forest builder asks for a number when the
## level starts: normally it's a brand new random one, but after replay_same() (the T key on the
## win / lose screen) the next level start gets the same number again, so the forest is built
## exactly the same way.
##
## Testing: start the game with  -- --forest=4821  to play that forest straight away.

var forest_number: int = 0      ## The forest being played right now (0 = none built yet).
var _replay_next: bool = false
var _forced: int = 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--forest="):
			_forced = int(arg.trim_prefix("--forest="))


## Called by the forest builder when a level starts. Returns the forest number to build.
func next_forest_number() -> int:
	if _forced > 0:
		forest_number = _forced
		_forced = 0
	elif _replay_next and forest_number > 0:
		pass   # same forest again
	else:
		forest_number = randi_range(1000, 99999)
	_replay_next = false
	return forest_number


## The next level start builds this same forest again (T on the end screens).
func replay_same() -> void:
	_replay_next = true


## The next level start builds a brand new random forest (R, Retry, Play again).
func new_forest() -> void:
	_replay_next = false
