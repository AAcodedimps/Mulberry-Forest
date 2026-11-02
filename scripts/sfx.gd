extends Node
## Sfx (global autoload): plays the game's sound effects and music. Every sound and both music
## loops were generated for this game (see CREDITS.md), and live in res://audio/.
##   Sfx.play("jump")                 a sound effect
##   Sfx.play("berry", -3.0, 1.2)     quieter (dB) and higher (pitch)
##   Sfx.start_music()                calm forest music; a tense layer fades in by itself when a
##                                    killer ghost gets close to the wanderer

# ======================= TUNING =======================
var sfx_volume_db: float = 0.0       ## Volume of all sound effects (0 = as made, -6 = half as loud).
var music_volume_db: float = -4.0    ## Volume of the music.
var tense_near: float = 250.0        ## A killer ghost this close (pixels) makes the music fully tense...
var tense_far: float = 1000.0        ## ...and the tension starts to creep in from this far away.
# ======================================================

const SOUNDS := {
	"jump": preload("res://audio/jump.res"),
	"land": preload("res://audio/land.res"),
	"pickup_stone": preload("res://audio/pickup_stone.res"),
	"pickup_power": preload("res://audio/pickup_power.res"),
	"pickup_cure": preload("res://audio/pickup_cure.res"),
	"throw": preload("res://audio/throw.res"),
	"ghost_hit": preload("res://audio/ghost_hit.res"),
	"ghost_rise": preload("res://audio/ghost_rise.res"),
	"mischief_rise": preload("res://audio/mischief_rise.res"),
	"caught": preload("res://audio/caught.res"),
	"trip": preload("res://audio/trip.res"),
	"fall": preload("res://audio/fall.res"),
	"tree_shake": preload("res://audio/tree_shake.res"),
	"berry": preload("res://audio/berry.res"),
	"gate_open": preload("res://audio/gate_open.res"),
	"gate_deny": preload("res://audio/gate_deny.res"),
	"squash": preload("res://audio/squash.res"),
	"smash": preload("res://audio/smash.res"),
	"shield": preload("res://audio/shield.res"),
	"ui_click": preload("res://audio/ui_click.res"),
	"win": preload("res://audio/win.res"),
}
const BEES := preload("res://audio/bees.res")
const MUSIC_CALM := preload("res://audio/music_calm.res")
const MUSIC_TENSE := preload("res://audio/music_tense.res")
const VOICES := 14

var _voices: Array[AudioStreamPlayer] = []
var _next: int = 0
var _calm: AudioStreamPlayer
var _tense: AudioStreamPlayer
var _tension: float = 0.0
var _fade_in: float = 0.0
var _music_on: bool = false
var _duck: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # music keeps going on menus and while paused
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_calm = AudioStreamPlayer.new()
	_calm.stream = MUSIC_CALM
	_calm.volume_db = -80.0
	add_child(_calm)
	_tense = AudioStreamPlayer.new()
	_tense.stream = MUSIC_TENSE
	_tense.volume_db = -80.0
	add_child(_tense)
	Powers.shield_blocked.connect(func(_hits_left): play("shield"))


## Stops and lets go of every sound when the game closes (so nothing is left playing at exit).
func _exit_tree() -> void:
	for p in _voices + [_calm, _tense]:
		p.stop()
		p.stream = null


## Plays a sound effect. `pitch_var` adds a little random pitch so repeats don't sound identical.
func play(id: String, volume_db: float = 0.0, pitch: float = 1.0, pitch_var: float = 0.04) -> void:
	var stream: AudioStream = SOUNDS.get(id)
	if stream == null:
		push_warning("Sfx: no sound called " + id)
		return
	var p: AudioStreamPlayer = null
	for i in VOICES:   # a free voice, or else the oldest one
		var v: AudioStreamPlayer = _voices[(_next + i) % VOICES]
		if not v.playing:
			p = v
			break
	if p == null:
		p = _voices[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.volume_db = volume_db + sfx_volume_db
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_var, pitch_var))
	p.play()


## The bee buzz loop (each beehive plays its own copy).
func bees_stream() -> AudioStream:
	return BEES


## Starts the music (it fades in). Calling it again while it plays does nothing.
func start_music() -> void:
	if _music_on:
		return
	_music_on = true
	_fade_in = 0.0
	_calm.play()
	_tense.play()   # same length as the calm loop, so the two stay in step


func _process(delta: float) -> void:
	if not _music_on:
		return
	_fade_in = minf(1.0, _fade_in + delta / 3.0)
	# How close is the nearest killer ghost?
	var target: float = 0.0
	var tree := get_tree()
	var player = tree.get_first_node_in_group("player")
	if player != null and not tree.paused:
		for g in tree.get_nodes_in_group("ghosts"):
			if g.is_in_group("mischief_ghosts"):
				continue
			var d: float = g.global_position.distance_to(player.global_position)
			target = maxf(target, clampf((tense_far - d) / (tense_far - tense_near), 0.0, 1.0))
	elif tree.paused:
		target = _tension   # hold it while paused
	_tension = move_toward(_tension, target, delta * (0.9 if target > _tension else 0.3))
	_duck = move_toward(_duck, 9.0 if tree.paused else 0.0, delta * 20.0)
	var base: float = music_volume_db - _duck + linear_to_db(maxf(_fade_in, 0.001))
	_calm.volume_db = base + linear_to_db(lerpf(1.0, 0.5, _tension))
	_tense.volume_db = base + linear_to_db(maxf(_tension * 0.95, 0.0005))
