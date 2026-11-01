@tool
extends Node2D
const OnScreen = preload("res://scripts/on_screen.gd")
## Poison flowers: a small patch of purple flowers on the path, with a soft glowing purple haze
## floating above them so you can see them coming. A nuisance hurdle: it never kills you and
## never makes a ghost.
##  - Touch them and you're poisoned: slower for a few seconds, with green bubbles around you.
##  - Touch them again while poisoned and the poison timer starts again from the beginning.
##  - Jump over the patch to get past safely.
##  - Bark Shield blocks the poison, and that counts as one of the shield's hits.
##  - Wild Berries cure the poison straight away.
## Place this node on the ground at the LEFT end of the patch.

# ======================= TUNING =======================
@export var slow_amount: float = 0.6    ## Your speed while poisoned (0.6 = 60%).
@export var poison_time: float = 4.0    ## How long the poison lasts, in seconds.
@export var patch_width: float = 120.0: ## How wide the patch of flowers is, in pixels.
	set(value):
		patch_width = value
		_build_flowers()
		queue_redraw()
# ======================================================
@export var hit_height: float = 22.0    ## How tall the poisonous part is (jump higher than this to be safe).
@export var hit_inset: float = 8.0      ## The poisonous part is this much narrower than the drawing on each side.

const FloatingText = preload("res://scenes/ui/floating_text.gd")
const Circles = preload("res://scripts/circles.gd")

const PETAL := Color("a347d6")
const PETAL_LIGHT := Color("d38cff")
const PETAL_DARK := Color("6e2a99")
const CENTRE := Color("f2e05c")
const STEM := Color("3e7a35")
const LEAF := Color("4f9a3c")
const HAZE := Color(0.8, 0.3, 1.0)

var _t: float = 0.0
var _player = null
var _touching: bool = false   # the wanderer is touching the flowers right now
var _shielded: bool = false   # this touch was blocked by Bark Shield
var _area: Area2D
var _flowers: Array = []      # [x, height, size, sway phase]


func _ready() -> void:
	_build_flowers()
	if Engine.is_editor_hint():
		return
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2   # the wanderer's layer
	_area.monitorable = false
	var shape := RectangleShape2D.new()
	var w: float = maxf(8.0, patch_width - 2.0 * hit_inset)
	shape.size = Vector2(w, hit_height)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(patch_width * 0.5, -hit_height * 0.5)
	_area.add_child(cs)
	add_child(_area)


func _build_flowers() -> void:
	_flowers.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var n: int = maxi(2, int(patch_width / 15.0))
	for i in n:
		var x: float = lerpf(8.0, patch_width - 8.0, (i + 0.5) / n) + rng.randf_range(-4.0, 4.0)
		_flowers.append([x, rng.randf_range(12.0, 22.0), rng.randf_range(1.0, 1.35), rng.randf() * TAU])


func _physics_process(delta: float) -> void:
	_t += delta
	if OnScreen.near(self):   # only redraw when on or near the screen
		queue_redraw()
	if Engine.is_editor_hint():
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	var touching: bool = _area.overlaps_body(_player) and not _player.is_locked()
	if touching and not _touching:
		# A new touch.
		_shielded = false
		if Powers.has_shield():
			_shielded = true
			if Powers.shield_block():
				FloatingText.spawn(_player.get_parent(), _player.global_position, "Blocked!", Color(0.6, 1.0, 0.65))
		else:
			_player.show_popup("Poisoned!")
	if touching and not _shielded:
		_player.poison(slow_amount, poison_time)   # keeps the timer full while you stay in the flowers
	_touching = touching


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	# Purple haze drifting above the patch (so you can see it coming)
	var mid: float = patch_width * 0.5
	for k in 5:
		var hx: float = mid + sin(_t * 0.5 + k * 1.9) * patch_width * 0.3
		var hy: float = -44.0 - k * 7.0 + sin(_t * 0.8 + k) * 6.0
		var hr: float = patch_width * 0.26 + 12.0 + k * 3.0
		var a: float = 0.14 + 0.05 * sin(_t * 1.3 + k * 2.1)
		Circles.circle(self, Vector2(hx, hy), hr, Color(HAZE.r, HAZE.g, HAZE.b, a))
	# Tiny glowing specks rising out of the haze
	for k in 6:
		var rise: float = fmod(_t * 14.0 + k * 13.0, 70.0)
		var sx: float = fmod(k * 37.0, patch_width - 10.0) + 5.0 + sin(_t * 1.5 + k) * 4.0
		Circles.circle(self, Vector2(sx, -8.0 - rise), 1.6, Color(0.85, 0.6, 1.0, 0.7 * (1.0 - rise / 70.0)))
	# Leaves at the base
	for f: Array in _flowers:
		var x: float = f[0]
		Circles.circle(self, Vector2(x - 4.0, -2.0), 4.0, LEAF)
		Circles.circle(self, Vector2(x + 4.0, -2.5), 3.5, STEM)
	# The flowers, swaying gently
	for f: Array in _flowers:
		var x: float = f[0]
		var h: float = f[1]
		var s: float = f[2]
		var sway: float = sin(_t * 1.6 + f[3]) * 2.0
		var top := Vector2(x + sway, -h)
		draw_line(Vector2(x, 0), top, STEM, 2.0)
		Circles.circle(self, top, 10.0 * s, Color(HAZE.r, HAZE.g, HAZE.b, 0.2))   # soft glow
		for p in 5:
			var ang: float = p * TAU / 5.0 + f[3]
			var col: Color = PETAL if p % 2 == 0 else PETAL_LIGHT
			Circles.circle(self, top + Vector2(cos(ang), sin(ang)) * 3.6 * s, 3.2 * s, col)
		Circles.circle(self, top, 2.0 * s, PETAL_DARK)
		Circles.circle(self, top, 1.2 * s, CENTRE)
