extends Node2D
## Builds a new random forest every run, like a small roguelite.
##  - The start is always "Edge of the Woods" (3 stones and the control signs) and the end is
##    always the Mulberry Grove clearing with the stone gate.
##  - The middle is made of hand-made chunks (scenes in res://scenes/levels/chunks/) picked at
##    random and joined end to end: mostly easy first, then medium, then hard near the end.
##    Two hard chunks never touch and the same chunk never comes twice in a row.
##  - Chunks next to each other with the same theme form one zone, and its name shows when you
##    walk in (Hollow Fork, Bee Meadow, Crumbling Ridge, Flood Stream).
##  - Stones, Forest Powers and Wild Berries are then placed on the chunks' Spot markers.
##  - Mulberry trees are spread through the forest: some right on the path, others on a detour
##    (up in the canopy, at the end of a little side path, or just past a hurdle). The three
##    regrowing stones go somewhere in the middle of the forest.
## The forest number (ForestRun.forest_number) is the random seed, so the same number always
## builds the same forest. The level script calls build() when the level starts.

# ======================= TUNING: the shape of every random forest =======================
var forest_screens_min: float = 22.0      ## Shortest forest, in screens (start and end included). One screen is about 914 pixels.
var forest_screens_max: float = 26.0      ## Longest forest, in screens.
var easy_chunks: int = 5                  ## How many easy chunks in the middle (they come first).
var medium_chunks: int = 5                ## How many medium chunks.
var hard_chunks: int = 3                  ## How many hard chunks (near the end, never two in a row).
var stones_per_screen: float = 2.0        ## Stones along the ground route, on average per screen (never fewer).
var canopy_stones_per_screen: float = 1.0 ## Extra stones up in the canopy, per screen of canopy.
var power_every_min_screens: float = 3.0  ## A Forest Power appears every 3 to 4 screens...
var power_every_max_screens: float = 4.0  ## ...(the exact gap is random between these two).
var first_power_screens: float = 1.5      ## The first power comes this many screens after Edge of the Woods.
var cure_chance: float = 0.75             ## Chance that poison flowers get a Wild Berries cure later on (otherwise no cure nearby).
var cure_min_screens: float = 2.0         ## The cure comes 2 to 3 screens after the flowers...
var cure_max_screens: float = 3.0         ## ...never right next to them.
var tree_count: int = 8                   ## How many mulberry trees in the forest.
var berries_per_tree_min: int = 1         ## Each tree has between this many...
var berries_per_tree_max: int = 2         ## ...and this many ripe berries.
var min_total_berries: int = 10           ## Never fewer berries than this in the whole forest (the gate wants 5: basket_size in player.gd).
var detour_tree_share: float = 0.6        ## About this share of the trees are on a detour (canopy, side path or just past a hurdle); the rest are right on the path.
# =========================================================================================

const SCREEN := 1280.0 / 1.4      # one screen of forest at the camera's zoom (about 914 pixels)
const CHUNK_DIR := "res://scenes/levels/chunks/"
const START_CHUNK := "res://scenes/levels/chunks/fixed/start_edge_of_the_woods.tscn"
const END_CHUNK := "res://scenes/levels/chunks/fixed/end_mulberry_grove.tscn"
const ZONE_SCRIPT := preload("res://scenes/levels/zone.gd")
const STONE_SCENE := preload("res://scenes/powers/stone_pickup.tscn")
const CURE_SCENE := preload("res://scenes/powers/wild_berries.tscn")
const POWER_SCENES := {
	"swift_mint": preload("res://scenes/powers/swift_mint.tscn"),
	"strength_fig": preload("res://scenes/powers/strength_fig.tscn"),
	"moonpetal": preload("res://scenes/powers/moonpetal.tscn"),
	"bark_shield": preload("res://scenes/powers/bark_shield.tscn"),
}
const THEMES := {
	"start": {"name": "Edge of the Woods", "backdrop": "none", "trunks": false, "canopy": ""},
	"hollow": {"name": "Hollow Fork", "backdrop": "hollow", "trunks": true, "canopy": ""},
	"meadow": {"name": "Bee Meadow", "backdrop": "meadow", "trunks": true, "canopy": "Hive Branches"},
	"ridge": {"name": "Crumbling Ridge", "backdrop": "ravine", "trunks": false, "canopy": ""},
	"stream": {"name": "Flood Stream", "backdrop": "stream", "trunks": false, "canopy": ""},
	"end": {"name": "Mulberry Grove", "backdrop": "grove", "trunks": false, "canopy": ""},
}

## Filled in by build() (the tests read these too).
var forest_number: int = 0
var width: float = 0.0
var gate = null                 ## The stone gate at the end.
var trees: Array = []           ## Every mulberry tree: {x, y, kind ("path", "canopy", "side", "hurdle"), berries, node}
var regrow_x: float = 0.0       ## where the three regrowing stones are
var placed: Array = []          ## Every chunk in order: {name, path, difficulty, theme, x, width}
var parts: Array = []           ## Every zone: {name, theme, x, width}
var stones: Array = []          ## x of every ground stone placed by the builder
var canopy_stones: Array = []   ## x of every canopy stone placed by the builder
var powers: Array = []          ## [x, power id] for every Forest Power
var cures: Array = []           ## x of every Wild Berries cure
var poisons: Array = []         ## [left x, right x] of every poison patch
var middle_from: float = 0.0    ## where the random chunks start...
var middle_to: float = 0.0      ## ...and end

var _rng := RandomNumberGenerator.new()
var _pool := {"easy": [], "medium": [], "hard": []}
var _spots: Array = []          # ground spots: {x, pos, chunk, used}
var _canopy_spots: Array = []
var _gaps: Array = []           # [left, right] of every hole, crumbling path and flood
var _trunks: Array = []         # x of every trunk
var _hives: Array = []          # position of every beehive
var _branches: Array = []       # [left, right] of every canopy branch
var _vines: Array = []          # x of every vine


# ---------------------------------------------------------------- building
## Builds the whole forest and returns how wide it is (pixels).
func build(level: Node = null) -> float:
	forest_number = ForestRun.next_forest_number()
	_rng.seed = forest_number
	_load_pool()
	var start_info: Dictionary = _chunk_info(START_CHUNK)
	var end_info: Dictionary = _chunk_info(END_CHUNK)
	var middle: Array = _plan_middle(start_info["width"] + end_info["width"])
	# Group the chunks into zones: neighbours with the same theme share one zone (and one name).
	var groups: Array = [{"theme": "start", "chunks": [start_info]}]
	for c in middle:
		if groups.back()["theme"] == c["theme"]:
			groups.back()["chunks"].append(c)
		else:
			groups.append({"theme": c["theme"], "chunks": [c]})
	groups.append({"theme": "end", "chunks": [end_info]})
	var x: float = 0.0
	for g in groups:
		x = _add_zone(g, x)
	width = x
	middle_from = start_info["width"]
	middle_to = width - end_info["width"]
	_scan_chunks()
	_place_powers()
	_place_cures()
	_place_trees()
	_place_regrowing_stones()
	_place_stones()
	if level != null:
		_fit_scenery(level)
	var berry_total: int = 0
	for t in trees:
		berry_total += t["berries"]
	print("[Forest] #%d built: %d chunks, %.1f screens, %d zones, %d stones (+%d canopy), %d powers, %d cures, %d trees with %d berries" % [
		forest_number, placed.size(), width / SCREEN, parts.size(), stones.size(), canopy_stones.size(), powers.size(), cures.size(), trees.size(), berry_total])
	return width


## Reads every chunk scene in the chunks folder and sorts them by difficulty.
func _load_pool() -> void:
	for d in _pool:
		_pool[d].clear()
	var files: PackedStringArray = ResourceLoader.list_directory(CHUNK_DIR)
	files.sort()
	for f in files:
		if not f.ends_with(".tscn"):
			continue
		var info: Dictionary = _chunk_info(CHUNK_DIR + f)
		if _pool.has(info["difficulty"]):
			_pool[info["difficulty"]].append(info)
	for d in _pool:
		if _pool[d].is_empty():
			push_error("[Forest] there are no %s chunks in %s" % [d, CHUNK_DIR])


func _chunk_info(path: String) -> Dictionary:
	var packed: PackedScene = load(path)
	var c = packed.instantiate()
	var info := {"path": path, "packed": packed, "name": path.get_file().get_basename(),
		"width": float(c.width), "difficulty": str(c.difficulty), "theme": str(c.theme)}
	c.free()
	return info


## Picks the middle chunks. Tries a few times to land inside the length limits.
func _plan_middle(fixed_width: float) -> Array:
	var counts := {"easy": easy_chunks, "medium": medium_chunks, "hard": hard_chunks}
	var best: Array = []
	var best_miss: float = INF
	for attempt in 80:
		var seq: Array = _pick_chunks(_difficulty_order(counts))
		var total: float = fixed_width
		for c in seq:
			total += c["width"]
		var screens: float = total / SCREEN
		var miss: float = maxf(forest_screens_min - screens, screens - forest_screens_max)
		if miss <= 0.0:
			return seq
		if miss < best_miss:
			best_miss = miss
			best = seq
		if attempt % 20 == 19:
			# Still not fitting: one chunk more or less (easy and medium only).
			if screens < forest_screens_min:
				counts["medium"] += 1
			elif counts["easy"] > 1:
				counts["easy"] -= 1
			elif counts["medium"] > 1:
				counts["medium"] -= 1
	push_warning("[Forest] couldn't fit %.0f-%.0f screens exactly; using the closest forest" % [forest_screens_min, forest_screens_max])
	return best


## The order of difficulties: mostly easy first, then medium, then hard near the end,
## with never two hard ones next to each other.
func _difficulty_order(counts: Dictionary) -> Array:
	var ranges := {"easy": Vector2(0.0, 0.5), "medium": Vector2(0.25, 0.85), "hard": Vector2(0.6, 1.0)}
	var items: Array = []
	for d in counts:
		for i in counts[d]:
			items.append([_rng.randf_range(ranges[d].x, ranges[d].y), d])
	items.sort_custom(func(a, b): return a[0] < b[0])
	var order: Array = []
	for it in items:
		order.append(it[1])
	for guard in 50:
		var bad: int = -1
		for i in order.size() - 1:
			if order[i] == "hard" and order[i + 1] == "hard":
				bad = i
				break
		if bad < 0:
			break
		# Pull the nearest non-hard chunk from further on in between the two hard ones...
		var moved: bool = false
		for j in range(bad + 2, order.size()):
			if order[j] != "hard":
				order.insert(bad + 1, order.pop_at(j))
				moved = true
				break
		if not moved:
			# ...or move the second hard one back to a gap between two non-hard ones.
			var h: String = order.pop_at(bad + 1)
			for k in range(bad, 0, -1):
				if order[k] != "hard" and order[k - 1] != "hard":
					order.insert(k, h)
					moved = true
					break
			if not moved:
				order.append(h)
	return order


## Fills each difficulty slot with a chunk. Neighbours tend to share a theme (so zones are a few
## chunks long), the same chunk never comes twice in a row and little-used chunks are preferred.
func _pick_chunks(order: Array) -> Array:
	var seq: Array = []
	var uses := {}
	var theme: String = ""
	var run_left: int = 0
	for d in order:
		if run_left <= 0:
			var themes: Array = ["hollow", "meadow", "ridge", "stream"]
			themes.erase(theme)
			theme = themes[_rng.randi() % themes.size()]
			run_left = _rng.randi_range(2, 4)
		var prev: String = seq.back()["path"] if not seq.is_empty() else ""
		var cands: Array = _pool[d].filter(func(c): return c["path"] != prev)
		if cands.is_empty():
			cands = _pool["medium"].filter(func(c): return c["path"] != prev)
		var pick = null
		var best: float = INF
		for c in cands:
			var score: float = (0.0 if c["theme"] == theme else 2.5) + uses.get(c["path"], 0) * 3.0 + _rng.randf() * 2.0
			if score < best:
				best = score
				pick = c
		if pick["theme"] != theme:
			theme = pick["theme"]
			run_left = _rng.randi_range(1, 3)
		run_left -= 1
		uses[pick["path"]] = uses.get(pick["path"], 0) + 1
		seq.append(pick)
	return seq


## Adds one zone (with its chunks) starting at x. Returns where the next zone starts.
func _add_zone(group: Dictionary, x: float) -> float:
	var th: Dictionary = THEMES[group["theme"]]
	var w: float = 0.0
	for c in group["chunks"]:
		w += c["width"]
	var zone := Node2D.new()
	zone.set_script(ZONE_SCRIPT)
	zone.name = "Zone%d_%s" % [parts.size() + 1, str(th["name"]).replace(" ", "")]
	zone.position = Vector2(x, 600)
	zone.zone_name = th["name"]
	zone.canopy_name = th["canopy"]
	zone.width = w
	zone.backdrop = th["backdrop"]
	zone.canopy_trunks = th["trunks"]
	add_child(zone)
	parts.append({"name": th["name"], "theme": group["theme"], "x": x, "width": w})
	var local_x: float = 0.0
	for c in group["chunks"]:
		var chunk: Node2D = c["packed"].instantiate()
		chunk.name = "%02d_%s" % [placed.size(), c["name"]]
		chunk.position = Vector2(local_x, 0)
		zone.add_child(chunk)
		placed.append({"name": c["name"], "path": c["path"], "difficulty": c["difficulty"], "theme": c["theme"],
			"x": x + local_x, "width": c["width"], "node": chunk})
		local_x += c["width"]
	return x + w


# ---------------------------------------------------------------- stones, powers, cures
func _scan_chunks() -> void:
	_spots.clear()
	_canopy_spots.clear()
	poisons.clear()
	_gaps.clear()
	_trunks.clear()
	_hives.clear()
	_branches.clear()
	_vines.clear()
	for i in placed.size():
		var info: Dictionary = placed[i]
		var chunk: Node = info["node"]
		for n in chunk.find_children("*", "", true, false):
			var sp: String = str(n.get_script().resource_path) if n.get_script() != null else ""
			var gx: float = n.global_position.x
			if sp.ends_with("poison_flowers.gd"):
				poisons.append([gx, gx + n.patch_width])
			elif sp.ends_with("hole.gd"):
				_gaps.append([gx - n.hole_width * 0.5, gx + n.hole_width * 0.5])
			elif sp.ends_with("collapsing_path.gd") or sp.ends_with("flood.gd"):
				_gaps.append([gx, gx + n.length])
			elif sp.ends_with("tree_trunk.gd"):
				_trunks.append(gx)
			elif sp.ends_with("beehive.gd"):
				_hives.append(n.global_position)
			elif sp.ends_with("branch_platform.gd"):
				_branches.append([gx - n.width * 0.5, gx + n.width * 0.5])
			elif sp.ends_with("vine.gd"):
				_vines.append(gx)
			if not (n is Marker2D):
				continue
			if i == 0 or i == placed.size() - 1:
				continue   # the start and the end keep exactly what's in them
			var spot := {"x": n.global_position.x, "pos": n.global_position, "chunk": chunk, "used": false}
			if n.name.begins_with("CanopySpot"):
				_canopy_spots.append(spot)
			elif n.name.begins_with("Spot"):
				_spots.append(spot)
	_spots.sort_custom(func(a, b): return a["x"] < b["x"])
	_canopy_spots.sort_custom(func(a, b): return a["x"] < b["x"])
	poisons.sort()


## A Forest Power every 3 to 4 screens. Bark Shield and Moonpetal are more likely just before a
## hard chunk; the same power never comes twice in a row.
func _place_powers() -> void:
	powers.clear()
	var hard_starts: Array = []
	for c in placed:
		if c["difficulty"] == "hard":
			hard_starts.append(c["x"])
	var next_x: float = middle_from + first_power_screens * SCREEN
	var last: String = ""
	while next_x < middle_to - SCREEN * 0.5:
		var spot = _nearest_free_spot(next_x, next_x - SCREEN * 0.4)
		if spot == null or spot["x"] > middle_to - SCREEN * 0.3:
			break
		var before_hard: bool = false
		for hx in hard_starts:
			if hx > spot["x"] - SCREEN * 0.3 and hx < spot["x"] + SCREEN * 2.5:
				before_hard = true
		var weights := {"swift_mint": 3.0, "strength_fig": 3.0, "bark_shield": 2.0, "moonpetal": 2.0}
		if before_hard:
			weights = {"swift_mint": 1.0, "strength_fig": 1.0, "bark_shield": 4.0, "moonpetal": 4.0}
		weights.erase(last)
		var id: String = _weighted(weights)
		_put(POWER_SCENES[id], spot)
		powers.append([spot["x"], id])
		last = id
		next_x = spot["x"] + _rng.randf_range(power_every_min_screens, power_every_max_screens) * SCREEN


## Wild Berries 2 to 3 screens after poison flowers (sometimes none), never next to any flowers.
func _place_cures() -> void:
	cures.clear()
	for p in poisons:
		var from: float = p[1] + cure_min_screens * SCREEN
		var to: float = p[1] + cure_max_screens * SCREEN
		var already: bool = false
		for c in cures:
			if c >= from and c <= to:
				already = true
		if already or _rng.randf() > cure_chance:
			continue
		var options: Array = []
		for s in _spots:
			if s["used"] or s["x"] < from or s["x"] > to or s["x"] > middle_to:
				continue
			var near_flowers: bool = false
			for q in poisons:
				if s["x"] > q[0] - SCREEN and s["x"] < q[1] + SCREEN:
					near_flowers = true
			if not near_flowers:
				options.append(s)
		if options.is_empty():
			continue
		var spot: Dictionary = options[_rng.randi() % options.size()]
		_put(CURE_SCENE, spot)
		cures.append(spot["x"])


## Stones: at least `stones_per_screen` per screen along the ground, spread evenly, plus a few
## up in the canopy.
func _place_stones() -> void:
	stones.clear()
	canopy_stones.clear()
	var gap: float = SCREEN / stones_per_screen
	var target: float = middle_from + gap * 0.5
	for s in _spots:
		if not s["used"] and s["x"] >= target:
			_put(STONE_SCENE, s)
			stones.append(s["x"])
			target = maxf(target + gap, s["x"] + gap * 0.6)
	# Top up if the spots left holes somewhere: fill the free spot that's furthest from any stone.
	var need: int = ceili((middle_to - middle_from) / SCREEN * stones_per_screen)
	while stones.size() < need:
		var best = null
		var best_d: float = -1.0
		for s in _spots:
			if s["used"]:
				continue
			var d: float = INF
			for x in stones:
				d = minf(d, absf(x - s["x"]))
			if d > best_d:
				best_d = d
				best = s
		if best == null:
			push_warning("[Forest] not enough Spot markers for %d stones" % need)
			break
		_put(STONE_SCENE, best)
		stones.append(best["x"])
	stones.sort()
	var cgap: float = SCREEN / maxf(canopy_stones_per_screen, 0.01)
	var last_x: float = -INF
	for s in _canopy_spots:
		if s["x"] - last_x >= cgap * 0.8:
			_put(STONE_SCENE, s)
			canopy_stones.append(s["x"])
			last_x = s["x"]


## The free ground spot closest to `x` (but not before `not_before`).
# ---------------------------------------------------------------- mulberry trees
const TREE_SCENE := preload("res://scenes/forest_end/mulberry_tree.tscn")
const REGROW_SCENE := preload("res://scenes/powers/regrowing_stone.tscn")
const BRANCH_SCENE := preload("res://scenes/world/branch_platform.tscn")
const VINE_SCENE := preload("res://scenes/hurdles/vine.tscn")
const PATH_TREE_SCALE := 0.7     # trees on the ground
const SMALL_TREE_SCALE := 0.5    # trees up on branches
const TREE_GAP := 600.0          # trees are at least this far apart


## Spreads the mulberry trees through the forest: the forest is split into `tree_count` equal
## stretches with one tree in each. The first tree is always right on the path; after that about
## `detour_tree_share` of them are on a detour.
func _place_trees() -> void:
	trees.clear()
	var kinds: Array = []
	var detours: int = roundi((tree_count - 1) * detour_tree_share)
	var detour_kinds: Array = ["canopy", "side", "hurdle"]
	for i in tree_count - 1:
		kinds.append(detour_kinds[_rng.randi() % 3] if i < detours else "path")
	_shuffle(kinds)
	kinds.insert(0, "path")
	var span: float = (middle_to - middle_from) / tree_count
	for i in tree_count:
		var from: float = middle_from + span * i + 150.0
		var to: float = middle_from + span * (i + 1) - 150.0
		var order: Array = [kinds[i]]
		for k in ["hurdle", "canopy", "side", "path"]:
			if not order.has(k):
				order.append(k)
		for kind in order:
			var where = _tree_place(kind, from, to)
			if where != null:
				_add_tree(kind, where)
				break
	# A stretch with no room (lots of holes and floods)? Fit the missing trees anywhere else.
	for kind in ["path", "hurdle", "canopy", "side"]:
		while trees.size() < tree_count:
			var where = _tree_place(kind, middle_from + 150.0, middle_to - 150.0)
			if where == null:
				break
			_add_tree(kind, where)
	trees.sort_custom(func(a, b): return a["x"] < b["x"])
	if trees.size() < tree_count:
		push_warning("[Forest] only found room for %d of %d mulberry trees" % [trees.size(), tree_count])
	# Berries: 1 or 2 per tree, topped up so there are always at least min_total_berries.
	var total: int = 0
	for t in trees:
		t["berries"] = _rng.randi_range(berries_per_tree_min, berries_per_tree_max)
		total += t["berries"]
	var guard: int = 0
	while total < min_total_berries and guard < 200:
		guard += 1
		var t: Dictionary = trees[_rng.randi() % trees.size()]
		if t["berries"] < berries_per_tree_max or guard > 100:
			t["berries"] += 1
			total += 1
	for t in trees:
		t["node"].berries_on_tree = t["berries"]
		t["node"]._build()


## Finds a place for a tree of this kind between from and to. Returns a Vector2 (where the trunk
## stands) or null.
func _tree_place(kind: String, from: float, to: float):
	var options: Array = []
	match kind:
		"path":
			var x: float = from
			while x <= to:
				if _ground_clear(x, 160.0) and not _canopy_over(x, 200.0) and _far_from_trees(x):
					options.append(Vector2(x, 600))
				x += 40.0
		"canopy":
			for s in _canopy_spots:
				var x: float = s["x"]
				if x < from or x > to or s["used"] or not _far_from_trees(x):
					continue
				var on: bool = false
				for b in _branches:
					if x - b[0] >= 110.0 and b[1] - x >= 110.0:
						on = true
				var vine_near: bool = false
				for v in _vines:
					if absf(v - x) < 70.0:
						vine_near = true
				if on and not vine_near:
					options.append(Vector2(x, 330))
		"side":
			# a little side path: a vine up to a short branch with nothing else up there
			var vx: float = from
			while vx <= to - 260.0:
				if _ground_clear(vx, 70.0) and not _canopy_over(vx + 130.0, 330.0) and _far_from_trees(vx + 230.0) and not _hive_near(Vector2(vx + 130.0, 330), 350.0):
					options.append(Vector2(vx + 230.0, 330))
				vx += 40.0
		"hurdle":
			# on the ground just past a hurdle (preferably under the canopy, so canopy walkers
			# have to drop down and cross the hurdle to reach it)
			var ends: Array = []
			for g in _gaps:
				ends.append(g[1])
			for p in poisons:
				ends.append(p[1])
			for h in _hives:
				if h.y > 500.0:
					ends.append(h.x + 60.0)
			for e in ends:
				var x: float = e + 140.0
				if x < from or x > to or not _far_from_trees(x):
					continue
				if _ground_clear(x, 110.0, 120.0, 150.0):
					options.append(Vector2(x, 600))
					if _canopy_over(x, 100.0):
						options.append(Vector2(x, 600))   # counts twice: more likely to be picked
	if options.is_empty():
		return null
	return options[_rng.randi() % options.size()]


func _add_tree(kind: String, where: Vector2) -> void:
	var info: Dictionary = {}
	for c in placed:
		if where.x >= c["x"] and where.x < c["x"] + c["width"]:
			info = c
	var chunk: Node2D = info["node"]
	if kind == "side":
		var vine_x: float = where.x - 230.0
		var branch = BRANCH_SCENE.instantiate()
		branch.width = 330.0
		branch.position = chunk.to_local(Vector2(where.x - 95.0, 330))
		branch.set_meta("side_path", true)
		chunk.add_child(branch)
		var vine = VINE_SCENE.instantiate()
		vine.set_meta("side_path", true)
		vine.length = 246.0
		vine.position = chunk.to_local(Vector2(vine_x, 324))
		chunk.add_child(vine)
		_branches.append([where.x - 260.0, where.x + 70.0])
		_vines.append(vine_x)
	var tree = TREE_SCENE.instantiate()
	tree.tree_scale = PATH_TREE_SCALE if where.y > 500.0 else SMALL_TREE_SCALE
	tree.berries_on_tree = berries_per_tree_max
	tree.position = chunk.to_local(where)
	chunk.add_child(tree)
	chunk.move_child(tree, 0)   # behind the ground, hurdles and pickups
	for s in _canopy_spots:
		if absf(s["x"] - where.x) < 150.0 and where.y < 500.0:
			s["used"] = true   # no stone right inside the tree
	trees.append({"x": where.x, "y": where.y, "kind": kind, "berries": 0, "node": tree, "chunk": info["name"]})


## The three regrowing stones (they grow back 8 seconds after you take them): on a clear bit of
## ground near the middle of the forest, so nobody runs completely dry of stones.
func _place_regrowing_stones() -> void:
	var mid: float = (middle_from + middle_to) * 0.5
	var best = null
	for s in _spots:
		if s["used"] or not _ground_clear(s["x"], 110.0):
			continue
		if best == null or absf(s["x"] - mid) < absf(best["x"] - mid):
			best = s
	if best == null:
		push_warning("[Forest] no room for the regrowing stones")
		return
	best["used"] = true
	regrow_x = best["x"]
	var chunk: Node2D = best["chunk"]
	for dx in [-35.0, 0.0, 35.0]:
		var st = REGROW_SCENE.instantiate()
		st.position = chunk.to_local(best["pos"] + Vector2(dx, 0))
		chunk.add_child(st)
	for s in _spots:
		if absf(s["x"] - best["x"]) < 100.0:
			s["used"] = true


## True if the ground around x is solid and free of hurdles (`left`/`right` override `half`).
func _ground_clear(x: float, half: float, left: float = -1.0, right: float = -1.0) -> bool:
	var a: float = x - (left if left >= 0.0 else half)
	var b: float = x + (right if right >= 0.0 else half)
	if a < middle_from or b > middle_to:
		return false
	for g in _gaps:
		if g[0] < b and g[1] > a:
			return false
	for p in poisons:
		if p[0] < b + 20.0 and p[1] > a - 20.0:
			return false
	for t in _trunks:
		if t > a - 90.0 and t < b + 90.0:
			return false
	for h in _hives:
		if h.y > 500.0 and absf(h.x - x) < 280.0:
			return false
	return true


func _canopy_over(x: float, half: float) -> bool:
	for b in _branches:
		if b[0] < x + half and b[1] > x - half:
			return true
	return false


func _hive_near(p: Vector2, dist: float) -> bool:
	for h in _hives:
		if h.distance_to(p) < dist:
			return true
	return false


func _far_from_trees(x: float) -> bool:
	for t in trees:
		if absf(t["x"] - x) < TREE_GAP:
			return false
	return true


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j: int = _rng.randi() % (i + 1)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


func _nearest_free_spot(x: float, not_before: float):
	var best = null
	for s in _spots:
		if s["used"] or s["x"] < not_before:
			continue
		if best == null or absf(s["x"] - x) < absf(best["x"] - x):
			best = s
	return best


func _put(scene: PackedScene, spot: Dictionary) -> void:
	spot["used"] = true
	var chunk: Node2D = spot["chunk"]
	var item: Node2D = scene.instantiate()
	item.position = chunk.to_local(spot["pos"])
	chunk.add_child(item)


func _weighted(weights: Dictionary) -> String:
	var total: float = 0.0
	for k in weights:
		total += weights[k]
	var r: float = _rng.randf() * total
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			return k
	return weights.keys().back()


# ---------------------------------------------------------------- scenery
## Stretches the background trees and fireflies over the whole forest, and finds the gate.
func _fit_scenery(level: Node) -> void:
	var last: Node = placed.back()["node"]
	gate = last.get_node_or_null("StoneGate")
	for pair in [["FarTrees/Layer", 0.2], ["MidTrees/Layer", 0.45], ["NearTrees/Layer", 0.7]]:
		var layer = level.get_node_or_null(pair[0])
		if layer == null:
			continue
		var density: float = layer.tree_count / maxf(1.0, layer.x_to - layer.x_from)
		var x_to: float = (width - SCREEN) * pair[1] + SCREEN * 2.2   # room for wide windows too
		layer.x_to = x_to
		layer.tree_count = int(density * (x_to - layer.x_from))
		layer.queue_redraw()
	for path in ["FirefliesBack", "FirefliesFront"]:
		var ff = level.get_node_or_null(path)
		if ff != null and ff.has_method("rebuild"):
			var old_w: float = maxf(1.0, ff.area.size.x)
			ff.count = int(ff.count * width / old_w)
			ff.area = Rect2(ff.area.position, Vector2(width, ff.area.size.y))
			ff.rebuild()
