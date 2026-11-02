@tool
extends Node2D
const OnScreen = preload("res://scripts/on_screen.gd")
const Circles = preload("res://scripts/circles.gd")
## A mulberry tree. The forest builder scatters several of them through the forest (on the
## path, up in the canopy, at the end of little side paths and just past hurdles).
## - A quick tap of F (X on gamepad) under it makes the wanderer throw one of their carried
##   stones straight up: the tree shakes and one ripe mulberry drops into the basket.
##   Each shake uses 1 stone; one shake = one berry. With no stones, nothing happens.
## - A tree with no berries left looks bare and won't shake.
## - When a mischief ghost steals a berry from the basket, it flies back to the tree it came from.
## Place this node on the ground (or on a branch), in the middle of the trunk.

# ======================= TUNING =======================
@export var berries_on_tree: int = 8           ## How many ripe mulberries hang in the tree (the forest builder sets 1 or 2).
@export var tree_scale: float = 1.0            ## How big the tree is drawn (1.0 = the old big tree). "Under the tree" shrinks with it.
@export var throw_time: float = 1.0            ## Seconds each tree throw takes. You can't throw again until it's done.
@export var under_tree_distance: float = 170.0 ## How close to the trunk (pixels, left or right) counts as "under the tree".
# ======================================================

const FloatingText = preload("res://scenes/ui/floating_text.gd")

const TRUNK := Color("2b1c20")
const TRUNK_LIGHT := Color("47303a")
const LEAF_DARK := Color("173f33")
const LEAF := Color("22604a")
const LEAF_LIGHT := Color("3a8a5c")
const BERRY := Color("3f0f58")
const BERRY_HI := Color("9a4cc8")
const STONE := Color("7d7d88")
const BARE := Color("4a3d33")      # the dull brown-green of a picked-clean tree
const CANOPY_CENTER := Vector2(0, -320)
const STONE_UP_TIME := 0.35     # how long the thrown stone takes to reach the leaves

var _slots: Array[Vector2] = []   # where each berry hangs
var _present: Array[bool] = []    # is that berry still on the tree?
var _given: Array[int] = []       # berries now in the basket (slot numbers)
var _flying: Array = []           # berries moving between tree and basket
var _leaves: Array = []           # canopy blobs: [position, radius, colour]
var _t: float = 0.0
var _shake: float = 0.0
var _busy: float = 0.0
var _up: float = -1.0             # thrown-stone progress 0..1 (-1 = none)
var _up_from := Vector2.ZERO
var _under: bool = false
var _prompt_text: String = ""
var _player = null


func _ready() -> void:
	scale = Vector2(tree_scale, tree_scale)
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group("mulberry_trees")


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024 + int(position.x)   # every tree gets its own leaf pattern
	_leaves.clear()
	for i in 26:
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(0.0, 1.0)
		var p := CANOPY_CENTER + Vector2(cos(a) * 150.0 * r, sin(a) * 95.0 * r)
		var col: Color = [LEAF_DARK, LEAF, LEAF][i % 3]
		_leaves.append([p, rng.randf_range(42.0, 68.0), col])
	for i in 9:
		var a2: float = rng.randf_range(PI * 1.05, PI * 1.6)
		_leaves.append([CANOPY_CENTER + Vector2(cos(a2) * 80.0, sin(a2) * 50.0), rng.randf_range(26.0, 40.0), LEAF_LIGHT])
	_slots.clear()
	_present.clear()
	for i in berries_on_tree:
		var x: float = lerpf(-130.0, 130.0, (i + 0.5) / float(berries_on_tree)) + rng.randf_range(-12.0, 12.0)
		var y: float = rng.randf_range(-375.0, -285.0)   # well above jumping height
		_slots.append(Vector2(x, y))
		_present.append(true)


func berries_left() -> int:
	var n: int = 0
	for p in _present:
		if p:
			n += 1
	return n


# ---------------------------------------------------------------- every frame
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
	var thrower = _player.stone_thrower
	var d: Vector2 = _player.global_position - global_position
	var under: bool = absf(d.x) <= under_tree_distance * tree_scale and absf(d.y) < 100.0 and not _player.is_locked()
	if under != _under:
		_under = under
		thrower.current_tree = self if under else null
		if not under:
			_set_prompt("")
	if under:
		if berries_left() == 0 and _flying.is_empty():
			_set_prompt("This tree is bare")
		elif _player.basket_full():
			_set_prompt("Your basket is full")
		elif berries_left() == 0:
			_set_prompt("No ripe mulberries left")
		else:
			_set_prompt("Press F to shake the tree (uses 1 stone)")
	_shake = maxf(0.0, _shake - delta)
	_busy = maxf(0.0, _busy - delta)
	if _up >= 0.0:
		_up += delta / STONE_UP_TIME
		if _up >= 1.0:
			_up = -1.0
			_stone_hits_leaves()
	_update_flying(delta)


func _set_prompt(text: String) -> void:
	if text == _prompt_text:
		return
	_prompt_text = text
	if text == "":
		get_tree().call_group("prompt_hint", "hide_prompt", self)
	else:
		get_tree().call_group("prompt_hint", "show_prompt", self, text)


# ---------------------------------------------------------------- shaking the tree
## Called by the stone thrower when F is tapped under the tree.
func try_shake(player) -> void:
	if _busy > 0.0:
		return   # the last throw isn't finished yet
	if player.basket_full():
		FloatingText.spawn(player.get_parent(), player.global_position, "Basket full!", Color(1, 0.9, 0.7))
		return
	if berries_left() == 0:
		FloatingText.spawn(player.get_parent(), player.global_position, "No berries left", Color(1, 0.9, 0.7))
		return
	if not player.stone_thrower.use_stone():
		get_tree().call_group("stone_counter", "shake")
		get_tree().call_group("message_hud", "show_message", "You need a stone to shake the tree")
		return
	_busy = throw_time
	_up = 0.0
	_up_from = to_local(player.global_position + Vector2(8.0 * player.facing, -85.0))


func _stone_hits_leaves() -> void:
	_shake = 0.4
	var choices: Array[int] = []
	for i in _slots.size():
		if _present[i]:
			choices.append(i)
	if choices.is_empty():
		return
	var slot: int = choices[randi() % choices.size()]
	_present[slot] = false
	var dur: float = maxf(0.3, throw_time - STONE_UP_TIME - 0.1)
	_flying.append({"slot": slot, "t": 0.0, "dur": dur, "drop": true, "from": _slots[slot]})


func _basket_point() -> Vector2:
	return to_local(_player.global_position + Vector2(-20.0 * _player.facing, -55.0))


func _update_flying(delta: float) -> void:
	for f in _flying.duplicate():
		f["t"] += delta / f["dur"]
		if f["t"] < 1.0:
			continue
		_flying.erase(f)
		var slot: int = f["slot"]
		if f["drop"]:
			if _player.basket_full():
				_present[slot] = true   # nowhere to put it: it pops back onto the branch
			else:
				_player.add_mulberry(self)
				_given.append(slot)
				FloatingText.spawn(_player.get_parent(), _player.global_position, "+1", Color(0.85, 0.6, 1.0))
		else:
			_present[slot] = true


## A mischief ghost stole one of this tree's berries from the basket: it flies back up onto
## the tree (if the tree is far away, the berry simply reappears on its branch).
func return_berry() -> void:
	if _given.is_empty():
		return
	var slot: int = _given.pop_back()
	if _player == null or _player.global_position.distance_to(global_position) > 1100.0:
		_present[slot] = true
		return
	_flying.append({"slot": slot, "t": 0.0, "dur": 0.9, "drop": false, "from": _basket_point()})


## True while this tree still has ripe berries (the berry pointer uses this).
func has_berries() -> bool:
	return berries_left() > 0


func _flying_pos(f: Dictionary) -> Vector2:
	var t: float = clampf(f["t"], 0.0, 1.0)
	var from: Vector2 = f["from"]
	var to: Vector2 = _basket_point() if f["drop"] else _slots[f["slot"]]
	var p: Vector2 = from.lerp(to, t)
	p.y -= sin(t * PI) * (30.0 if f["drop"] else 60.0)   # a little arc
	return p


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	var sway := Vector2(sin(_t * 0.9) * 3.0, 0.0)
	var jolt := Vector2(sin(_t * 70.0) * _shake * 16.0, cos(_t * 55.0) * _shake * 5.0)
	# Roots and trunk
	draw_colored_polygon(PackedVector2Array([Vector2(-75, 2), Vector2(-40, -20), Vector2(-34, -150), Vector2(-26, -240),
		Vector2(26, -240), Vector2(34, -150), Vector2(40, -20), Vector2(78, 2)]), TRUNK)
	for x: float in [-18.0, -4.0, 12.0]:
		draw_line(Vector2(x, -20), Vector2(x + 4.0, -220), TRUNK_LIGHT, 2.0)
	# Branches up into the leaves
	for b: Array in [[Vector2(-8, -225), Vector2(-120, -300)], [Vector2(8, -225), Vector2(115, -310)],
			[Vector2(0, -235), Vector2(-30, -380)], [Vector2(4, -235), Vector2(60, -390)]]:
		draw_line(b[0], b[1] + sway * 0.5 + jolt * 0.5, TRUNK, 13.0)
	# Leafy top (shakes when hit). Once every berry is gone the tree looks bare: thin, dull leaves.
	var bare: bool = berries_left() == 0 and _flying.is_empty()
	for i in _leaves.size():
		var leaf: Array = _leaves[i]
		if bare:
			if i % 3 == 0:
				continue
			Circles.circle(self, leaf[0] + sway + jolt, leaf[1] * 0.8, Color(leaf[2]).lerp(BARE, 0.6))
		else:
			Circles.circle(self, leaf[0] + sway + jolt, leaf[1], leaf[2])
	# Ripe mulberries, swaying on their stems
	for i in _slots.size():
		if _present[i]:
			var p: Vector2 = _slots[i] + Vector2(sin(_t * 1.7 + i) * 4.0, 0.0) + jolt
			draw_line(p + Vector2(0, -12), p, Color("3a2a1a"), 1.5)
			_berry(p)
	# Stone flying up into the tree
	if _up >= 0.0:
		var e: float = 1.0 - pow(1.0 - _up, 2.0)
		var sp: Vector2 = _up_from.lerp(CANOPY_CENTER + Vector2(0, 40), e)
		Circles.circle(self, sp, 6.0, STONE)
		Circles.circle(self, sp + Vector2(-2, -2), 2.0, Color("d0d0d8"))
	# Berries dropping into the basket / flying back
	for f in _flying:
		_berry(_flying_pos(f))


func _berry(p: Vector2) -> void:
	# Small trees draw their berries a bit bigger and brighter, so you can spot them from afar.
	var k: float = 1.5 / sqrt(clampf(tree_scale, 0.3, 1.0)) if tree_scale < 0.99 else 1.0
	var glow: float = 0.6 + 0.4 * sin(_t * 2.5 + p.x)
	Circles.circle(self, p, 15.0 * k, Color(0.8, 0.4, 1.0, 0.22 * glow))
	Circles.circle(self, p, 9.0 * k, Color(0.85, 0.5, 1.0, 0.38 * glow))
	for o: Vector2 in [Vector2(-2.5, -2), Vector2(2.5, -2), Vector2(0, 1.5), Vector2(0, -4.5)]:
		Circles.circle(self, p + o * k, 3.4 * k, BERRY)
	Circles.circle(self, p + Vector2(-1.8, -3.0) * k, 1.4 * k, BERRY_HI)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var a: float = TAU * i / 12.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)
