@tool
extends Area2D
const OnScreen = preload("res://scripts/on_screen.gd")
const Circles = preload("res://scripts/circles.gd")
## Shared setup for every collectible power (stones now; Swift Mint, Strength Fig, Moonpetal,
## Bark Shield and Wild Berries later). The item floats at chest height, bobs gently, glows
## and sparkles. It is collected the moment ANY part of the wanderer's body touches it
## (running, jumping or climbing through it), with a little pop sound and a "+1" above the
## wanderer. If the wanderer can't carry more, it simply stays floating.
##
## Place the node ON THE GROUND; the item floats `float_height` above that spot.
## To make a new pickup: create a script that starts with
##     @tool
##     extends "res://scenes/powers/floating_pickup.gd"
## and give it two functions:
##     func _try_collect(body) -> bool   # give the item to the wanderer; return true if taken
##     func _draw_item() -> void         # draw the item centred on (0, 0)

# ======================= TUNING (shared by all floating pickups) =======================
@export var float_height: float = 60.0   ## How high above the ground it floats, in pixels (60 = the wanderer's chest, a little below the eyes).
@export var bob_amount: float = 6.0      ## How far it bobs up and down, in pixels.
@export var bob_speed: float = 2.5       ## How fast it bobs (higher = quicker).
# ========================================================================================
@export var glow_color: Color = Color(1.0, 0.95, 0.7)    ## Colour of the soft glow and sparkles.
@export var pickup_radius: float = 20.0                  ## Size of the touch area around the item.
@export var popup_text: String = "+1"
@export var popup_color: Color = Color(1.0, 0.95, 0.7)

const FloatingText = preload("res://scenes/ui/floating_text.gd")

static var _pop_sound: AudioStreamWAV

var _t: float = 0.0
var _pop: float = -1.0   # -1 = waiting to be collected; 0..1 = popping


func _ready() -> void:
	_t = position.x * 0.013   # so neighbouring pickups don't bob in perfect step
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	collision_mask = 2        # the wanderer's layer
	monitorable = false
	var shape := CircleShape2D.new()
	shape.radius = pickup_radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -float_height)
	add_child(cs)


func _physics_process(delta: float) -> void:
	_t += delta
	if OnScreen.near(self):   # only redraw when on or near the screen
		queue_redraw()
	if Engine.is_editor_hint():
		return
	if _pop >= 0.0:
		_pop += delta / 0.25
		modulate.a = clampf(1.0 - _pop, 0.0, 1.0)
		if _pop >= 1.0:
			_after_pop()
		return
	for body in get_overlapping_bodies():
		if _try_collect(body):
			_on_collected(body)
			return


## Override: give the item to `body`. Return true if it was taken.
func _try_collect(_body) -> bool:
	return false


## Override: draw the item centred on (0, 0).
func _draw_item() -> void:
	pass


## Called when the pop animation has finished. Normally the pickup is gone for good;
## pickups that grow back override this.
func _after_pop() -> void:
	queue_free()


func _on_collected(body) -> void:
	_pop = 0.0
	set_deferred("monitoring", false)
	FloatingText.spawn(body.get_parent(), body.global_position, popup_text, popup_color)
	_play_pop()


func _item_center() -> Vector2:
	return Vector2(0, -float_height + sin(_t * bob_speed) * bob_amount)


func _draw() -> void:
	var c: Vector2 = _item_center()
	var pulse: float = 0.75 + 0.25 * sin(_t * 3.0)
	# Faint shadow on the ground so you can tell it's floating
	if _pop < 0.0:
		var shadow := PackedVector2Array()
		for i in 12:
			var a: float = TAU * i / 12.0
			shadow.append(Vector2(cos(a) * 10.0, -2.0 + sin(a) * 3.0))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.18))
	# Soft glow
	var g := glow_color
	Circles.circle(self, c, 28.0, Color(g.r, g.g, g.b, 0.08 * pulse))
	Circles.circle(self, c, 19.0, Color(g.r, g.g, g.b, 0.16 * pulse))
	# Twinkling sparkles circling the item
	for k in 3:
		var a2: float = _t * 1.6 + k * TAU / 3.0
		var sp: Vector2 = c + Vector2(cos(a2) * 21.0, sin(a2) * 13.0)
		var s: float = 1.5 + 2.0 * maxf(0.0, sin(_t * 4.0 + k * 2.0))
		draw_line(sp + Vector2(-s, 0), sp + Vector2(s, 0), Color(g.r, g.g, g.b, 0.9), 1.4)
		draw_line(sp + Vector2(0, -s), sp + Vector2(0, s), Color(g.r, g.g, g.b, 0.9), 1.4)
	# The item itself (grows a little as it pops)
	var grow: float = 1.0 if _pop < 0.0 else 1.0 + _pop * 0.7
	draw_set_transform(c, 0.0, Vector2(grow, grow))
	_draw_item()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Burst of sparkles when collected
	if _pop >= 0.0:
		for k in 8:
			var a3: float = k * TAU / 8.0
			var p: Vector2 = c + Vector2(cos(a3), sin(a3)) * (8.0 + _pop * 26.0)
			Circles.circle(self, p, 2.5 * (1.0 - _pop * 0.6), Color(g.r, g.g, g.b, 1.0))


# ---------------------------------------------------------------- pop sound
func _play_pop() -> void:
	if _pop_sound == null:
		_pop_sound = _make_pop_sound()
	var player := AudioStreamPlayer.new()
	player.stream = _pop_sound
	player.volume_db = -8.0
	get_parent().add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## Builds a tiny "pop" sound in code (a quick rising blip), so no sound file is needed.
static func _make_pop_sound() -> AudioStreamWAV:
	var rate: int = 22050
	var length: float = 0.09
	var n: int = int(rate * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase: float = 0.0
	for i in n:
		var t: float = float(i) / rate
		var freq: float = lerpf(600.0, 1400.0, t / length)
		phase += TAU * freq / rate
		var sample: float = sin(phase) * exp(-t * 40.0) * 0.6
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
