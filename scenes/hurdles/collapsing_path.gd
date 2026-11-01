@tool
extends Node2D
## A collapsing path: old wooden planks over a gap. A deadly hurdle, like the hole.
## Step on it and it trembles and cracks for `tremble_time` seconds, then the planks drop away.
## If you're still on it, you fall: exactly like a hole (white flash, back at the edge you came
## from, 1.5 s of blinking, GameEvents.deadly_mistake). After `rebuild_time` seconds the planks
## float back up into place. Moonpetal (Powers.world_time_scale) makes all of this slower.
## Place this node at the LEFT end of the gap, level with the top of the ground; the ground on
## both sides must stop at the gap's edges.

# ======================= TUNING =======================
@export var tremble_time: float = 1.5   ## Seconds the planks shake and crack after you step on them, before they drop.
@export var rebuild_time: float = 6.0   ## Seconds after dropping before the planks float back up.
@export var length: float = 300.0:      ## How long the path (and the gap under it) is, in pixels.
	set(value):
		length = value
		queue_redraw()
# ======================================================
@export var edge_margin: float = 42.0   ## How far from the gap's edge you reappear after falling.
@export var depth: float = 140.0

enum Phase { INTACT, TREMBLING, FALLEN, REBUILDING }

const PLANK_W := 30.0
const DROP_TIME := 0.8      # how long the falling planks stay visible
const RISE_TIME := 1.0      # how long the planks take to float back up
const WOOD := Color("8a5a32")
const WOOD_DARK := Color("6a4223")
const WOOD_LIGHT := Color("a8743f")
const POST := Color("4a2f1c")
const CRACK := Color("2a1a10")

var _phase: Phase = Phase.INTACT
var _timer: float = 0.0
var _t: float = 0.0
var _player = null
var _entry_side: int = 0     # which end the wanderer stepped on from: -1 left, +1 right, 0 unknown


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var plank_shape := RectangleShape2D.new()
	plank_shape.size = Vector2(length, 20.0)
	$Planks/CollisionShape2D.shape = plank_shape
	$Planks/CollisionShape2D.position = Vector2(length * 0.5, 10.0)
	var lid_shape := RectangleShape2D.new()
	lid_shape.size = Vector2(length + 8.0, 8.0)
	$Lid/CollisionShape2D.shape = lid_shape
	$Lid/CollisionShape2D.position = Vector2(length * 0.5, 4.0)
	var zone_shape := RectangleShape2D.new()
	zone_shape.size = Vector2(length, 100.0)
	$FallZone/CollisionShape2D.shape = zone_shape
	$FallZone/CollisionShape2D.position = Vector2(length * 0.5, 110.0)
	$FallZone.body_entered.connect(_on_fall_zone_body_entered)


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if Engine.is_editor_hint():
		return
	delta *= Powers.world_time_scale()   # Moonpetal: trembling and rebuilding take longer
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	match _phase:
		Phase.INTACT:
			if _player != null and _player_on_planks():
				_phase = Phase.TREMBLING
				_timer = 0.0
				var px: float = _player.global_position.x - global_position.x
				_entry_side = -1 if px < length * 0.5 else 1
		Phase.TREMBLING:
			_timer += delta
			if _timer >= tremble_time:
				_phase = Phase.FALLEN
				_timer = 0.0
				$Planks/CollisionShape2D.set_deferred("disabled", true)
		Phase.FALLEN:
			_timer += delta
			if _timer >= rebuild_time:
				_phase = Phase.REBUILDING
				_timer = 0.0
		Phase.REBUILDING:
			_timer += delta
			if _timer >= RISE_TIME:
				_phase = Phase.INTACT
				_timer = 0.0
				$Planks/CollisionShape2D.set_deferred("disabled", false)


func _player_on_planks() -> bool:
	var p: Vector2 = _player.global_position - global_position
	return _player.is_on_floor() and p.x > 0.0 and p.x < length and absf(p.y) < 6.0


## Same as falling into a hole.
func _on_fall_zone_body_entered(body) -> void:
	if not body.has_method("respawn_at") or body.is_blinking():
		return
	# Back to the end you stepped on from (or, if unknown, the side you last stood on).
	var came_from_left: bool = body.last_floor_x < global_position.x + length * 0.5
	if _entry_side != 0:
		came_from_left = _entry_side < 0
	_entry_side = 0
	var x: float = global_position.x - edge_margin if came_from_left else global_position.x + length + edge_margin
	body.call_deferred("respawn_at", Vector2(x, global_position.y))
	get_tree().call_group("screen_flash", "flash")
	GameEvents.report_deadly_mistake()


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	# The dark gap under the planks
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(length, 0), Vector2(length, depth), Vector2(0, depth)]),
		PackedColorArray([Color("2a1840"), Color("2a1840"), Color("05030a"), Color("05030a")]))
	# Posts holding the ends
	draw_rect(Rect2(-4, -12, 8, 34), POST)
	draw_rect(Rect2(length - 4, -12, 8, 34), POST)
	var n: int = maxi(1, int(round(length / PLANK_W)))
	var w: float = length / n
	for i in n:
		var base := Vector2(i * w + w * 0.5, 7.0)
		var offset := Vector2.ZERO
		var angle: float = 0.0
		var alpha: float = 1.0
		var cracked: float = 0.0
		match _phase:
			Phase.TREMBLING:
				var prog: float = clampf(_timer / tremble_time, 0.0, 1.0)
				offset = Vector2(sin(_t * 50.0 + i * 1.7) * 1.5, sin(_t * 63.0 + i * 2.3) * 2.0) * (0.3 + prog)
				angle = sin(_t * 40.0 + i) * 0.04 * prog
				cracked = prog
			Phase.FALLEN:
				var dt: float = _timer - (i % 4) * 0.04
				if dt > DROP_TIME:
					continue
				dt = maxf(dt, 0.0)
				offset = Vector2(sin(i * 3.1) * 30.0 * dt, 0.5 * 1400.0 * dt * dt)
				angle = sin(i * 1.9) * 3.0 * dt
				alpha = 1.0 - dt / DROP_TIME
				cracked = 1.0
			Phase.REBUILDING:
				var p: float = clampf((_timer / RISE_TIME) * 1.5 - float(i) / n * 0.5, 0.0, 1.0)
				var e: float = 1.0 - pow(1.0 - p, 3.0)
				offset = Vector2(0, (1.0 - e) * 130.0)
				alpha = p
		_plank(base + offset, w, angle, alpha, cracked, i)


func _plank(c: Vector2, w: float, angle: float, alpha: float, cracked: float, i: int) -> void:
	var xf := Transform2D(angle, c)
	var hw: float = w * 0.5 - 1.5
	var body := PackedVector2Array([Vector2(-hw, -7), Vector2(hw, -7), Vector2(hw, 7), Vector2(-hw, 7)])
	var col: Color = WOOD if i % 2 == 0 else WOOD_DARK
	draw_colored_polygon(xf * body, Color(col.r, col.g, col.b, alpha))
	draw_line(xf * Vector2(-hw, -6), xf * Vector2(hw, -6), Color(WOOD_LIGHT.r, WOOD_LIGHT.g, WOOD_LIGHT.b, alpha), 1.5)
	draw_line(xf * Vector2(-hw + 3, 1), xf * Vector2(hw - 5, 2), Color(WOOD_DARK.r, WOOD_DARK.g, WOOD_DARK.b, alpha), 1.0)
	for nx: float in [-hw + 3.0, hw - 3.0]:
		draw_circle(xf * Vector2(nx, -2), 1.3, Color(0.75, 0.75, 0.8, alpha))
	# Cracks spread as it trembles (each plank cracks at its own moment)
	if cracked > fmod(i * 0.37, 1.0) * 0.8:
		var cc := Color(CRACK.r, CRACK.g, CRACK.b, alpha)
		draw_polyline(xf * PackedVector2Array([Vector2(-2, -7), Vector2(2, -2), Vector2(-1, 2), Vector2(3, 7)]), cc, 1.5)
