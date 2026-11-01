extends Node
## Powers (global autoload): keeps track of which Forest Powers are switched on and for how long.
## Pickups call activate(). Anything in the game can ask about the powers, for example:
##   Powers.is_strong()          - Strength Fig is on (trunks break; later: flood waves can't push you)
##   Powers.is_time_slowed()     - Moonpetal is on
##   Powers.world_time_scale()   - multiply your delta by this to slow down with Moonpetal (ghosts do;
##                                 later bees, flood waves and collapsing paths can too)
##   Powers.has_shield()         - Bark Shield is up
##   Powers.speed_multiplier() / jump_multiplier() - used by the wanderer

# ======================= TUNING =======================
var power_time: float = 10.0            ## How long each power lasts, in seconds.
var swift_speed_boost: float = 0.4      ## Swift Mint: run this much faster (0.4 = 40% faster).
var strength_jump_boost: float = 0.25   ## Strength Fig: jump this much higher (0.25 = 25% higher).
var moonpetal_slow: float = 0.5         ## Moonpetal: everything except you runs at this speed (0.5 = half speed).
var shield_hits: int = 3                ## Bark Shield: how many hits it blocks before it breaks.
var shield_knock_back_time: float = 5.0 ## Bark Shield: a killer ghost that touches it is knocked back this many seconds along its path.
# ======================================================

signal power_started(id: String)
signal power_ended(id: String)
signal shield_blocked(hits_left: int)

const SWIFT_MINT := "swift_mint"
const STRENGTH_FIG := "strength_fig"
const MOONPETAL := "moonpetal"
const BARK_SHIELD := "bark_shield"
const NAMES := {
	"swift_mint": "Swift Mint",
	"strength_fig": "Strength Fig",
	"moonpetal": "Moonpetal",
	"bark_shield": "Bark Shield",
}

var shield_hits_left: int = 0
var _time_left := {}            # power id -> seconds left
var _block_cooldown: float = 0.0


## Clears every power (the level calls this when it starts or restarts).
func reset() -> void:
	_time_left.clear()
	shield_hits_left = 0
	_block_cooldown = 0.0


## Switches a power on for power_time seconds. Grabbing it again while it's on resets the timer.
func activate(id: String) -> void:
	var fresh: bool = not _time_left.has(id)
	_time_left[id] = power_time
	if id == BARK_SHIELD:
		shield_hits_left = shield_hits
	if fresh:
		power_started.emit(id)


func is_active(id: String) -> bool:
	return _time_left.has(id)


func time_left(id: String) -> float:
	return _time_left.get(id, 0.0)


func active_powers() -> Array:
	return _time_left.keys()


func is_strong() -> bool:
	return is_active(STRENGTH_FIG)


func is_time_slowed() -> bool:
	return is_active(MOONPETAL)


func world_time_scale() -> float:
	return moonpetal_slow if is_time_slowed() else 1.0


func speed_multiplier() -> float:
	return 1.0 + swift_speed_boost if is_active(SWIFT_MINT) else 1.0


func jump_multiplier() -> float:
	return 1.0 + strength_jump_boost if is_strong() else 1.0


func has_shield() -> bool:
	return is_active(BARK_SHIELD)


## The shield blocked something. Uses up one hit (hits within a moment of each other count once);
## the shield breaks when it runs out of hits. Returns true if this hit was counted.
func shield_block() -> bool:
	if not has_shield() or _block_cooldown > 0.0:
		return false
	_block_cooldown = 0.5
	shield_hits_left -= 1
	shield_blocked.emit(shield_hits_left)
	if shield_hits_left <= 0:
		_end(BARK_SHIELD)
	return true


func _process(delta: float) -> void:
	_block_cooldown = maxf(0.0, _block_cooldown - delta)
	for id in _time_left.keys():
		_time_left[id] -= delta
		if _time_left[id] <= 0.0:
			_end(id)


func _end(id: String) -> void:
	if not _time_left.has(id):
		return
	_time_left.erase(id)
	if id == BARK_SHIELD:
		shield_hits_left = 0
	power_ended.emit(id)
