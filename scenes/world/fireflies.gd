@tool
extends Node2D
const Circles = preload("res://scripts/circles.gd")
## A swarm of small glowing fireflies that drift and twinkle inside `area` (world coordinates).

@export var count: int = 20
@export var area: Rect2 = Rect2(0, 260, 2560, 320)
@export var swarm_seed: int = 3

var _base: Array[Vector2] = []
var _phase: Array[float] = []
var _speed: Array[float] = []
var _t: float = 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = swarm_seed
	for i in count:
		_base.append(Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y)))
		_phase.append(rng.randf() * TAU)
		_speed.append(rng.randf_range(0.3, 0.8))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	for i in _base.size():
		var ph: float = _phase[i]
		var sp: float = _speed[i]
		var p: Vector2 = _base[i] + Vector2(sin(_t * sp + ph) * 40.0, cos(_t * sp * 0.7 + ph * 1.3) * 22.0)
		var glow: float = 0.55 + 0.45 * sin(_t * 2.6 + ph * 3.0)
		Circles.circle(self, p, 9.0, Color(1.0, 0.95, 0.45, 0.07 * glow))
		Circles.circle(self, p, 4.5, Color(1.0, 0.92, 0.4, 0.25 * glow))
		Circles.circle(self, p, 1.8, Color(1.0, 1.0, 0.75, 0.4 + 0.6 * glow))
