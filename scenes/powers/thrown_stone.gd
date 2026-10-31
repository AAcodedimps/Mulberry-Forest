extends Node2D
## A stone in flight. Every physics frame it falls a little (gravity) and moves along its arc.
## It asks every node in the "stone_targets" group whether the stone touches it; the first
## one that says yes gets `on_stone_hit(stone)` and the stone is used up. If it hits the
## ground instead, it breaks into a puff of dust.
##
## To make something a new stone target, add it to the "stone_targets" group and give it:
##   func stone_hit_test(point: Vector2) -> bool   # true if a stone at `point` touches you
##   func on_stone_hit(stone) -> void             # react (stone.stun_time etc. are available)

const GROUND_MASK := 1 | 4   # world + branch platforms

var velocity := Vector2.ZERO
var gravity: float = 1300.0
var stun_time: float = 3.0
var knock_back_time: float = 3.0

var _age: float = 0.0
var _dust: float = -1.0   # -1 = flying; 0..1 = dust puff playing


func _physics_process(delta: float) -> void:
	_age += delta
	if _dust >= 0.0:
		_dust += delta / 0.4
		queue_redraw()
		if _dust >= 1.0:
			queue_free()
		return
	var from: Vector2 = global_position
	velocity.y += gravity * delta
	var to: Vector2 = from + velocity * delta
	# Did we hit a target?
	for target in get_tree().get_nodes_in_group("stone_targets"):
		if target.has_method("stone_hit_test") and target.stone_hit_test(to):
			target.on_stone_hit(self)
			queue_free()
			return
	# Did we hit the ground (or a wall / branch)?
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters2D.create(from, to, GROUND_MASK))
	if not hit.is_empty():
		global_position = hit.position
		_dust = 0.0
		queue_redraw()
		return
	global_position = to
	rotation += 10.0 * delta * signf(velocity.x)
	if global_position.y > 900.0 or _age > 8.0:
		queue_free()   # fell into a hole or out of the world


func _draw() -> void:
	if _dust < 0.0:
		draw_circle(Vector2.ZERO, 7.0, Color("6b6b73"))
		draw_circle(Vector2(-0.5, -0.5), 6.0, Color("8e8e96"))
		draw_circle(Vector2(-2.0, -2.0), 2.2, Color("cfcfd6"))
		return
	# Puff of dust and a few chips
	for k in 7:
		var a: float = PI + PI * k / 6.0
		var r: float = 4.0 + _dust * 22.0
		var p := Vector2(cos(a) * r, sin(a) * r * 0.6 - _dust * 6.0)
		draw_circle(p, 6.0 * (1.0 - _dust * 0.5), Color(0.72, 0.66, 0.58, 0.55 * (1.0 - _dust)))
	for k in 3:
		var p2 := Vector2((k - 1) * 10.0 * _dust * 1.5, -12.0 * _dust + 30.0 * _dust * _dust)
		draw_circle(p2, 2.0, Color(0.55, 0.55, 0.6, 1.0 - _dust))
