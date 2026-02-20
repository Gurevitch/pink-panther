extends Node2D

## Builds all interior room elements at runtime:
## architecture, props, NPCs, decorative details, lighting overlays, and animations.

# Animation references
var _flame: Polygon2D
var _flame_inner: Polygon2D
var _flag_node: Node2D
var _bm_visual: Node2D
var _prof_visual: Node2D
var _bm_base_y: float = 0.0
var _prof_base_y: float = 0.0
var _time: float = 0.0

# Glow overlay references
var _candle_glow: Polygon2D
var _door_glow: Polygon2D

# Hand-drawn deterministic RNG
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 2007  # fixed seed for consistent hand-drawn look
	_build_glow_overlays()
	_build_candle_sconce()
	_build_british_flag()
	_build_door_exit()
	_build_stone_bust()
	_build_framed_painting()
	_build_display_case()
	_build_floor_plant()
	_build_door_shoes()
	_build_british_man()
	_build_old_professor()
	_build_shadow_pools()
	_build_dust_motes()
	_build_foreground_elements()


func _process(delta: float) -> void:
	_time += delta
	_animate()


# =========================================================
#  HELPERS
# =========================================================

func _poly(parent: Node, verts: PackedVector2Array, col: Color,
		outline_w: float = 2.5, pos: Vector2 = Vector2.ZERO) -> Polygon2D:
	var p := Polygon2D.new()
	p.position = pos

	# --- hand-drawn: wobble vertices ---
	var wobbled := _wobble_verts(verts)
	p.polygon = wobbled

	# --- hand-drawn: jitter fill color ---
	p.color = _jitter_col(col)

	if outline_w > 0.0:
		# main outline (wobbled)
		var o := Line2D.new()
		var pts := wobbled.duplicate()
		pts.append(wobbled[0])
		o.points = pts
		o.width = outline_w
		o.default_color = Color.BLACK
		o.width_curve = _make_width_curve()
		p.add_child(o)

		# sketch overlay — second lighter outline, extra offset
		var s := Line2D.new()
		var spts := _wobble_verts(verts, 1.6)  # different wobble
		var closed := spts.duplicate()
		closed.append(spts[0])
		s.points = closed
		s.width = outline_w * 0.38
		s.default_color = Color(0, 0, 0, 0.20)
		p.add_child(s)

	parent.add_child(p)
	return p


func _line(parent: Node, pts: PackedVector2Array, col: Color,
		w: float = 2.0, pos: Vector2 = Vector2.ZERO) -> Line2D:
	var l := Line2D.new()
	# --- hand-drawn: wobble points ---
	var wobbled := PackedVector2Array()
	for pt in pts:
		wobbled.append(pt + Vector2(
			_rng.randf_range(-1.2, 1.2),
			_rng.randf_range(-1.2, 1.2)
		))
	l.points = wobbled
	l.default_color = col
	l.width = w
	l.width_curve = _make_width_curve()
	l.position = pos
	parent.add_child(l)
	return l


# --- hand-drawn helper: wobble a vertex array ---
func _wobble_verts(verts: PackedVector2Array, max_amount: float = 2.0) -> PackedVector2Array:
	# scale wobble by shape diagonal
	var mn := verts[0]
	var mx := verts[0]
	for v in verts:
		mn = Vector2(min(mn.x, v.x), min(mn.y, v.y))
		mx = Vector2(max(mx.x, v.x), max(mx.y, v.y))
	var diag := (mx - mn).length()
	var amount := clampf(diag * 0.016, 0.3, max_amount)

	var result := PackedVector2Array()
	for v in verts:
		result.append(v + Vector2(
			_rng.randf_range(-amount, amount),
			_rng.randf_range(-amount, amount)
		))
	return result


# --- hand-drawn helper: jitter a color slightly ---
func _jitter_col(col: Color) -> Color:
	if col.a < 0.5:
		return col  # don't jitter transparent fills
	return Color(
		clampf(col.r + _rng.randf_range(-0.025, 0.025), 0.0, 1.0),
		clampf(col.g + _rng.randf_range(-0.025, 0.025), 0.0, 1.0),
		clampf(col.b + _rng.randf_range(-0.025, 0.025), 0.0, 1.0),
		col.a
	)


# --- hand-drawn helper: varying-width curve for Line2D ---
func _make_width_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.80 + _rng.randf_range(0.0, 0.30)))
	c.add_point(Vector2(0.2, 0.88 + _rng.randf_range(0.0, 0.25)))
	c.add_point(Vector2(0.5, 0.95 + _rng.randf_range(0.0, 0.15)))
	c.add_point(Vector2(0.8, 0.88 + _rng.randf_range(0.0, 0.25)))
	c.add_point(Vector2(1.0, 0.80 + _rng.randf_range(0.0, 0.30)))
	return c


## Creates a ClickableObject Area2D, returns [area, visual_node].
## Caller must call add_child(area) on this node AFTER building visuals.
func _clickable(obj_name: String, pos: Vector2,
		coll_size: Vector2, coll_offset: Vector2 = Vector2.ZERO) -> Array:
	var area := ClickableObject.new()
	area.name = obj_name.replace(" ", "")
	area.object_name = obj_name
	area.position = pos
	area.input_pickable = true
	area.add_to_group("clickable")

	var visual := Node2D.new()
	visual.name = "Visual"
	area.add_child(visual)

	var coll := CollisionShape2D.new()
	coll.position = coll_offset
	var shape := RectangleShape2D.new()
	shape.size = coll_size
	coll.shape = shape
	area.add_child(coll)

	return [area, visual]


# =========================================================
#  LIGHTING OVERLAYS — warm glow circles (additive blend)
# =========================================================

func _build_glow_overlays() -> void:
	# Candle warm glow — large soft circle
	_candle_glow = Polygon2D.new()
	_candle_glow.name = "CandleGlow"
	_candle_glow.position = Vector2(210, 148)
	_candle_glow.z_index = 1
	var glow_pts := PackedVector2Array()
	for i in range(24):
		var a := float(i) / 24.0 * TAU
		glow_pts.append(Vector2(cos(a) * 110, sin(a) * 95))
	_candle_glow.polygon = glow_pts
	_candle_glow.color = Color(1.0, 0.82, 0.45, 0.06)
	add_child(_candle_glow)

	# Door warm glow — wider, softer
	_door_glow = Polygon2D.new()
	_door_glow.name = "DoorGlow"
	_door_glow.position = Vector2(480, 310)
	_door_glow.z_index = 1
	var dg_pts := PackedVector2Array()
	for i in range(24):
		var a := float(i) / 24.0 * TAU
		dg_pts.append(Vector2(cos(a) * 130, sin(a) * 150))
	_door_glow.polygon = dg_pts
	_door_glow.color = Color(0.90, 0.95, 0.80, 0.04)
	add_child(_door_glow)

	# Left window glow
	var lw_glow := Polygon2D.new()
	lw_glow.name = "LeftWindowGlow"
	lw_glow.position = Vector2(134, 156)
	lw_glow.z_index = 1
	var lwg_pts := PackedVector2Array()
	for i in range(16):
		var a := float(i) / 16.0 * TAU
		lwg_pts.append(Vector2(cos(a) * 65, sin(a) * 55))
	lw_glow.polygon = lwg_pts
	lw_glow.color = Color(1.0, 0.88, 0.55, 0.05)
	add_child(lw_glow)

	# Right window glow
	var rw_glow := Polygon2D.new()
	rw_glow.name = "RightWindowGlow"
	rw_glow.position = Vector2(810, 164)
	rw_glow.z_index = 1
	var rwg_pts := PackedVector2Array()
	for i in range(16):
		var a := float(i) / 16.0 * TAU
		rwg_pts.append(Vector2(cos(a) * 65, sin(a) * 55))
	rw_glow.polygon = rwg_pts
	rw_glow.color = Color(1.0, 0.88, 0.55, 0.045)
	add_child(rw_glow)


# =========================================================
#  ROOM ARCHITECTURE
# =========================================================

func _build_candle_sconce() -> void:
	var sconce := Node2D.new()
	sconce.name = "CandleSconce"
	sconce.position = Vector2(190, 145)
	sconce.z_index = 2

	# warm glow behind candle (closer/brighter halo)
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(-45, -55), Vector2(0, -78), Vector2(45, -55),
		Vector2(55, 0), Vector2(45, 55), Vector2(0, 65),
		Vector2(-45, 55), Vector2(-55, 0)
	])
	glow.color = Color(1.0, 0.82, 0.45, 0.09)
	glow.position = Vector2(38, -18)
	sconce.add_child(glow)

	# second tighter glow (brighter center)
	var glow2 := Polygon2D.new()
	glow2.polygon = PackedVector2Array([
		Vector2(-22, -30), Vector2(0, -40), Vector2(22, -30),
		Vector2(28, 0), Vector2(22, 28), Vector2(0, 35),
		Vector2(-22, 28), Vector2(-28, 0)
	])
	glow2.color = Color(1.0, 0.90, 0.55, 0.12)
	glow2.position = Vector2(38, -22)
	sconce.add_child(glow2)

	# wall bracket backplate
	_poly(sconce,
		PackedVector2Array([
			Vector2(0, 0), Vector2(4, -7), Vector2(10, -10),
			Vector2(18, -8), Vector2(22, -2), Vector2(22, 10),
			Vector2(18, 16), Vector2(10, 18), Vector2(4, 16), Vector2(0, 10)
		]),
		Color(0.72, 0.58, 0.24), 2.5)

	# bracket arm (curvy)
	_poly(sconce,
		PackedVector2Array([
			Vector2(18, 1), Vector2(28, -5), Vector2(36, -6),
			Vector2(42, -2), Vector2(44, 4), Vector2(42, 10),
			Vector2(36, 14), Vector2(28, 12), Vector2(18, 9)
		]),
		Color(0.72, 0.58, 0.24), 2.0)

	# decorative curl on bracket
	_line(sconce,
		PackedVector2Array([
			Vector2(20, 14), Vector2(24, 20), Vector2(30, 22),
			Vector2(34, 18)
		]),
		Color(0.60, 0.48, 0.20), 2.0)

	# candle holder cup
	_poly(sconce,
		PackedVector2Array([
			Vector2(-8, 0), Vector2(8, 0), Vector2(7, -6),
			Vector2(3, -8), Vector2(-3, -8), Vector2(-7, -6)
		]),
		Color(0.72, 0.58, 0.24), 1.8, Vector2(40, -2))

	# candle body (with wax drip detail)
	_poly(sconce,
		PackedVector2Array([
			Vector2(-4, 0), Vector2(4, 0), Vector2(5, -10),
			Vector2(4, -22), Vector2(3, -26), Vector2(-3, -26),
			Vector2(-4, -22), Vector2(-5, -10)
		]),
		Color(0.92, 0.88, 0.78), 2.0, Vector2(40, -7))

	# wax drip
	_poly(sconce,
		PackedVector2Array([
			Vector2(3, -8), Vector2(5, -8), Vector2(6, -2),
			Vector2(5, 2), Vector2(3, 0)
		]),
		Color(0.90, 0.85, 0.72), 0.0, Vector2(40, -7))

	# flame outer (animated)
	_flame = _poly(sconce,
		PackedVector2Array([
			Vector2(-5, 5), Vector2(-6, 0), Vector2(-4, -10),
			Vector2(0, -18), Vector2(4, -10), Vector2(6, 0), Vector2(5, 5)
		]),
		Color(1.0, 0.85, 0.2), 0.0, Vector2(40, -33))

	# flame inner
	_flame_inner = _poly(sconce,
		PackedVector2Array([
			Vector2(-2, 3), Vector2(-3, 0), Vector2(-2, -6),
			Vector2(0, -11), Vector2(2, -6), Vector2(3, 0), Vector2(2, 3)
		]),
		Color(1.0, 0.55, 0.1), 0.0, Vector2(40, -33))

	add_child(sconce)


func _build_british_flag() -> void:
	var result := _clickable("British Flag", Vector2(480, 42),
			Vector2(54, 42), Vector2(0, 0))
	var area: ClickableObject = result[0]
	var visual: Node2D = result[1]
	area.z_index = 3
	_flag_node = visual

	# pole
	_line(visual,
		PackedVector2Array([Vector2(0, 20), Vector2(0, 50)]),
		Color(0.4, 0.3, 0.2), 3.5)

	# pole finial (ball top)
	_poly(visual,
		PackedVector2Array([
			Vector2(-3, 0), Vector2(0, -4), Vector2(3, 0),
			Vector2(0, 3)
		]),
		Color(0.72, 0.58, 0.24), 1.5, Vector2(0, 18))

	# white background with slight fold
	_poly(visual,
		PackedVector2Array([
			Vector2(-26, -18), Vector2(26, -18),
			Vector2(27, 0), Vector2(26, 18), Vector2(-26, 18), Vector2(-27, 0)
		]),
		Color.WHITE, 2.5)

	# fold shadow line
	_line(visual,
		PackedVector2Array([Vector2(-27, 0), Vector2(0, 2), Vector2(27, 0)]),
		Color(0.75, 0.75, 0.75), 1.5)

	# blue corners
	for q in [
		PackedVector2Array([Vector2(-26, -18), Vector2(-5, -18), Vector2(-5, -4), Vector2(-26, -4)]),
		PackedVector2Array([Vector2(5, -18), Vector2(26, -18), Vector2(26, -4), Vector2(5, -4)]),
		PackedVector2Array([Vector2(-26, 4), Vector2(-5, 4), Vector2(-5, 18), Vector2(-26, 18)]),
		PackedVector2Array([Vector2(5, 4), Vector2(26, 4), Vector2(26, 18), Vector2(5, 18)]),
	]:
		_poly(visual, q, Color(0.0, 0.22, 0.52), 0.0)

	# red cross
	_poly(visual,
		PackedVector2Array([
			Vector2(-26, -4), Vector2(26, -4), Vector2(26, 4), Vector2(-26, 4)
		]),
		Color(0.8, 0.13, 0.2), 0.0)
	_poly(visual,
		PackedVector2Array([
			Vector2(-5, -18), Vector2(5, -18), Vector2(5, 18), Vector2(-5, 18)
		]),
		Color(0.8, 0.13, 0.2), 0.0)

	# White diagonals (saltire lines)
	_line(visual,
		PackedVector2Array([Vector2(-26, -18), Vector2(26, 18)]),
		Color(0.95, 0.95, 0.95), 2.0)
	_line(visual,
		PackedVector2Array([Vector2(26, -18), Vector2(-26, 18)]),
		Color(0.95, 0.95, 0.95), 2.0)

	add_child(area)


# =========================================================
#  DOOR EXIT — clickable zone over the central door
# =========================================================

func _build_door_exit() -> void:
	var result := _clickable("Door Exit", Vector2(480, 240),
			Vector2(100, 180), Vector2(0, 0))
	var area: ClickableObject = result[0]
	area.z_index = 1
	# Door exit arrow indicator (subtle)
	var visual: Node2D = result[1]
	_poly(visual,
		PackedVector2Array([
			Vector2(-8, 10), Vector2(0, -6), Vector2(8, 10)
		]),
		Color(1.0, 1.0, 0.8, 0.35), 0.0, Vector2(0, -70))
	_poly(visual,
		PackedVector2Array([
			Vector2(-5, 6), Vector2(0, -3), Vector2(5, 6)
		]),
		Color(1.0, 1.0, 0.8, 0.25), 0.0, Vector2(0, -58))
	add_child(area)


# =========================================================
#  PROPS
# =========================================================

func _build_stone_bust() -> void:
	var result := _clickable("Stone Bust", Vector2(72, 390),
			Vector2(50, 105), Vector2(0, -52))
	var area: ClickableObject = result[0]
	var visual: Node2D = result[1]
	area.z_index = 4

	# pedestal (wider, more detailed)
	_poly(visual,
		PackedVector2Array([
			Vector2(-24, 0), Vector2(24, 0), Vector2(22, -6),
			Vector2(20, -8), Vector2(20, -20), Vector2(22, -22),
			Vector2(24, -24), Vector2(-24, -24), Vector2(-22, -22),
			Vector2(-20, -20), Vector2(-20, -8), Vector2(-22, -6)
		]),
		Color(0.48, 0.46, 0.44), 3.0)

	# pedestal top plate
	_poly(visual,
		PackedVector2Array([
			Vector2(-20, -22), Vector2(20, -22), Vector2(18, -28), Vector2(-18, -28)
		]),
		Color(0.52, 0.50, 0.48), 2.0)

	# torso (more detailed shoulder shape)
	_poly(visual,
		PackedVector2Array([
			Vector2(-18, 0), Vector2(18, 0), Vector2(20, -10),
			Vector2(20, -18), Vector2(18, -28), Vector2(16, -36),
			Vector2(12, -42), Vector2(8, -44), Vector2(-8, -44),
			Vector2(-12, -42), Vector2(-16, -36), Vector2(-18, -28),
			Vector2(-20, -18), Vector2(-20, -10)
		]),
		Color(0.60, 0.60, 0.58), 3.0, Vector2(0, -28))

	# head (more detailed profile)
	_poly(visual,
		PackedVector2Array([
			Vector2(-10, 0), Vector2(10, 0), Vector2(12, -8),
			Vector2(13, -18), Vector2(12, -26), Vector2(10, -32),
			Vector2(4, -36), Vector2(0, -37), Vector2(-4, -36),
			Vector2(-10, -32), Vector2(-12, -26), Vector2(-13, -18),
			Vector2(-12, -8)
		]),
		Color(0.66, 0.66, 0.64), 3.0, Vector2(0, -72))

	# brow ridge
	_line(visual,
		PackedVector2Array([
			Vector2(-8, 0), Vector2(-4, -3), Vector2(0, -4),
			Vector2(4, -3), Vector2(8, 0)
		]),
		Color(0.54, 0.54, 0.52), 2.5, Vector2(0, -94))

	# nose
	_poly(visual,
		PackedVector2Array([
			Vector2(-2, 0), Vector2(0, -8), Vector2(2, 0),
			Vector2(4, 4), Vector2(-4, 4)
		]),
		Color(0.64, 0.64, 0.62), 2.0, Vector2(0, -88))

	# eye sockets (shadows)
	_poly(visual,
		PackedVector2Array([
			Vector2(-3, -2), Vector2(0, -3), Vector2(3, -2),
			Vector2(3, 1), Vector2(0, 2), Vector2(-3, 1)
		]),
		Color(0.52, 0.52, 0.50), 0.0, Vector2(-6, -96))
	_poly(visual,
		PackedVector2Array([
			Vector2(-3, -2), Vector2(0, -3), Vector2(3, -2),
			Vector2(3, 1), Vector2(0, 2), Vector2(-3, 1)
		]),
		Color(0.52, 0.52, 0.50), 0.0, Vector2(6, -96))

	# chin
	_line(visual,
		PackedVector2Array([
			Vector2(-4, 0), Vector2(-2, 4), Vector2(2, 4), Vector2(4, 0)
		]),
		Color(0.58, 0.58, 0.56), 2.0, Vector2(0, -78))

	# highlight on forehead
	_poly(visual,
		PackedVector2Array([
			Vector2(-5, -2), Vector2(0, -4), Vector2(5, -2),
			Vector2(3, 1), Vector2(-3, 1)
		]),
		Color(0.74, 0.74, 0.72), 0.0, Vector2(0, -102))

	add_child(area)


func _build_framed_painting() -> void:
	var result := _clickable("Framed Painting", Vector2(790, 148),
			Vector2(100, 80), Vector2(0, 0))
	var area: ClickableObject = result[0]
	var visual: Node2D = result[1]
	area.z_index = 2
	area.rotation = 0.04

	# outer frame (thick ornate gold)
	_poly(visual,
		PackedVector2Array([
			Vector2(-50, -40), Vector2(50, -40),
			Vector2(50, 40), Vector2(-50, 40)
		]),
		Color(0.75, 0.58, 0.22), 4.0)

	# frame bevel (inner darker band)
	_poly(visual,
		PackedVector2Array([
			Vector2(-46, -36), Vector2(46, -36),
			Vector2(46, 36), Vector2(-46, 36)
		]),
		Color(0.62, 0.48, 0.18), 2.0)

	# frame inner edge (dark recess)
	_poly(visual,
		PackedVector2Array([
			Vector2(-42, -32), Vector2(42, -32),
			Vector2(42, 32), Vector2(-42, 32)
		]),
		Color(0.40, 0.30, 0.12), 1.5)

	# canvas sky
	_poly(visual,
		PackedVector2Array([
			Vector2(-39, -29), Vector2(39, -29),
			Vector2(39, 29), Vector2(-39, 29)
		]),
		Color(0.42, 0.62, 0.82), 0.0)

	# clouds in painting
	_poly(visual,
		PackedVector2Array([
			Vector2(-20, -18), Vector2(-14, -22), Vector2(-6, -20),
			Vector2(2, -23), Vector2(10, -18), Vector2(6, -14),
			Vector2(-2, -15), Vector2(-10, -13), Vector2(-18, -14)
		]),
		Color(0.85, 0.88, 0.92), 0.0)

	# mountains (more detailed)
	_poly(visual,
		PackedVector2Array([
			Vector2(-39, 29), Vector2(-30, 2), Vector2(-22, -10),
			Vector2(-14, 0), Vector2(-5, 8), Vector2(4, -4),
			Vector2(12, -16), Vector2(22, -6), Vector2(30, 4),
			Vector2(39, 29)
		]),
		Color(0.28, 0.44, 0.25), 0.0)

	# snow caps (more peaks)
	for peak in [
		PackedVector2Array([Vector2(-25, -6), Vector2(-22, -10), Vector2(-18, -5)]),
		PackedVector2Array([Vector2(9, -10), Vector2(12, -16), Vector2(16, -9)]),
		PackedVector2Array([Vector2(-32, 4), Vector2(-30, 2), Vector2(-27, 5)]),
	]:
		_poly(visual, peak, Color(0.94, 0.94, 0.96), 0.0)

	# foreground trees in painting
	_poly(visual,
		PackedVector2Array([
			Vector2(-34, 29), Vector2(-30, 8), Vector2(-26, 15),
			Vector2(-22, 4), Vector2(-18, 12), Vector2(-14, 29)
		]),
		Color(0.15, 0.32, 0.12), 0.0)

	# frame corner ornaments (gold dots)
	for corner_pos in [Vector2(-46, -36), Vector2(46, -36), Vector2(46, 36), Vector2(-46, 36)]:
		_poly(visual,
			PackedVector2Array([
				Vector2(-3, 0), Vector2(0, -3), Vector2(3, 0), Vector2(0, 3)
			]),
			Color(0.82, 0.65, 0.28), 0.0, corner_pos)

	add_child(area)


func _build_display_case() -> void:
	var result := _clickable("Display Case", Vector2(865, 420),
			Vector2(82, 100), Vector2(0, -50))
	var area: ClickableObject = result[0]
	var visual: Node2D = result[1]
	area.z_index = 4

	# cabinet body (slightly trapezoidal for perspective)
	_poly(visual,
		PackedVector2Array([
			Vector2(-38, 0), Vector2(38, 0), Vector2(40, -14),
			Vector2(40, -84), Vector2(38, -90), Vector2(36, -92),
			Vector2(-36, -92), Vector2(-38, -90),
			Vector2(-40, -84), Vector2(-40, -14)
		]),
		Color(0.16, 0.30, 0.38), 3.5)

	# cabinet top edge
	_poly(visual,
		PackedVector2Array([
			Vector2(-38, -90), Vector2(38, -90), Vector2(36, -96), Vector2(-36, -96)
		]),
		Color(0.20, 0.35, 0.42), 2.0)

	# glass front (semi-transparent, with reflection)
	_poly(visual,
		PackedVector2Array([
			Vector2(-32, -12), Vector2(32, -12),
			Vector2(32, -84), Vector2(-32, -84)
		]),
		Color(0.60, 0.75, 0.85, 0.25), 0.0)

	# glass reflection streak
	_line(visual,
		PackedVector2Array([
			Vector2(-28, -78), Vector2(-20, -20)
		]),
		Color(0.80, 0.90, 1.0, 0.15), 4.0)

	# upper shelf line
	_line(visual,
		PackedVector2Array([Vector2(-32, -56), Vector2(32, -56)]),
		Color(0.10, 0.20, 0.26), 2.5)

	# middle shelf line
	_line(visual,
		PackedVector2Array([Vector2(-32, -34), Vector2(32, -34)]),
		Color(0.10, 0.20, 0.26), 2.5)

	# === Top shelf trinkets ===
	# Red bottle
	_poly(visual,
		PackedVector2Array([
			Vector2(-3, 0), Vector2(3, 0), Vector2(3, -10),
			Vector2(2, -12), Vector2(1, -16), Vector2(-1, -16),
			Vector2(-2, -12), Vector2(-3, -10)
		]),
		Color(0.82, 0.20, 0.16), 1.5, Vector2(-18, -58))

	# Green vase
	_poly(visual,
		PackedVector2Array([
			Vector2(-4, 0), Vector2(4, 0), Vector2(5, -6),
			Vector2(3, -14), Vector2(2, -16), Vector2(-2, -16),
			Vector2(-3, -14), Vector2(-5, -6)
		]),
		Color(0.18, 0.58, 0.28), 1.5, Vector2(-4, -57))

	# Gold sphere
	_poly(visual,
		PackedVector2Array([
			Vector2(-4, -1), Vector2(-2, -5), Vector2(2, -5),
			Vector2(4, -1), Vector2(2, 3), Vector2(-2, 3)
		]),
		Color(0.85, 0.72, 0.18), 1.0, Vector2(14, -62))

	# Blue figurine
	_poly(visual,
		PackedVector2Array([
			Vector2(-2, 0), Vector2(2, 0), Vector2(3, -8),
			Vector2(0, -14), Vector2(-3, -8)
		]),
		Color(0.22, 0.45, 0.72), 1.0, Vector2(24, -58))

	# === Middle shelf trinkets ===
	# Purple crystal
	_poly(visual,
		PackedVector2Array([
			Vector2(-3, 0), Vector2(0, -12), Vector2(3, 0)
		]),
		Color(0.58, 0.18, 0.55), 1.0, Vector2(-14, -36))

	# Orange pot
	_poly(visual,
		PackedVector2Array([
			Vector2(-5, 0), Vector2(5, 0), Vector2(4, -8),
			Vector2(3, -10), Vector2(-3, -10), Vector2(-4, -8)
		]),
		Color(0.80, 0.45, 0.15), 1.5, Vector2(4, -35))

	# Small white teacup
	_poly(visual,
		PackedVector2Array([
			Vector2(-3, 0), Vector2(3, 0), Vector2(4, -4),
			Vector2(3, -6), Vector2(-3, -6), Vector2(-4, -4)
		]),
		Color(0.90, 0.88, 0.82), 1.0, Vector2(20, -35))

	# === Bottom shelf trinkets ===
	# Red sphere
	_poly(visual,
		PackedVector2Array([
			Vector2(-3, -1), Vector2(-1, -4), Vector2(1, -4),
			Vector2(3, -1), Vector2(1, 2), Vector2(-1, 2)
		]),
		Color(0.72, 0.15, 0.12), 0.0, Vector2(-10, -16))

	# Green gem
	_poly(visual,
		PackedVector2Array([
			Vector2(-4, 0), Vector2(0, -7), Vector2(4, 0)
		]),
		Color(0.15, 0.62, 0.25), 1.0, Vector2(8, -14))

	# Blue bottle
	_poly(visual,
		PackedVector2Array([
			Vector2(-2, 0), Vector2(2, 0), Vector2(2, -8),
			Vector2(1, -12), Vector2(-1, -12), Vector2(-2, -8)
		]),
		Color(0.22, 0.50, 0.72), 1.0, Vector2(22, -13))

	add_child(area)


func _build_floor_plant() -> void:
	var plant := Node2D.new()
	plant.name = "FloorPlant"
	plant.position = Vector2(375, 472)
	plant.z_index = 3

	# stem (slightly curved)
	_line(plant,
		PackedVector2Array([
			Vector2(0, 0), Vector2(-2, -10), Vector2(-1, -22), Vector2(0, -30)
		]),
		Color(0.32, 0.22, 0.10), 2.0)

	# leaves (more of them, varied)
	_poly(plant,
		PackedVector2Array([
			Vector2(0, -24), Vector2(-10, -36), Vector2(-5, -40), Vector2(0, -32)
		]),
		Color(0.22, 0.52, 0.18), 1.5)
	_poly(plant,
		PackedVector2Array([
			Vector2(0, -28), Vector2(9, -40), Vector2(5, -44), Vector2(0, -36)
		]),
		Color(0.28, 0.58, 0.22), 1.5)
	_poly(plant,
		PackedVector2Array([
			Vector2(0, -18), Vector2(-11, -26), Vector2(-7, -30), Vector2(0, -24)
		]),
		Color(0.20, 0.46, 0.16), 1.5)
	# tiny new sprout
	_poly(plant,
		PackedVector2Array([
			Vector2(0, -8), Vector2(5, -16), Vector2(3, -18), Vector2(0, -14)
		]),
		Color(0.35, 0.65, 0.30), 1.0)

	add_child(plant)


func _build_door_shoes() -> void:
	var shoes := Node2D.new()
	shoes.name = "DoorShoes"
	shoes.position = Vector2(530, 476)
	shoes.z_index = 3

	# Left shoe
	_poly(shoes,
		PackedVector2Array([
			Vector2(-12, 0), Vector2(-14, -4), Vector2(-10, -8),
			Vector2(-4, -10), Vector2(8, -10), Vector2(14, -6),
			Vector2(14, -2), Vector2(10, 0)
		]),
		Color(0.30, 0.22, 0.14), 2.5)

	# Right shoe (slightly rotated, offset)
	_poly(shoes,
		PackedVector2Array([
			Vector2(-10, 2), Vector2(-12, -2), Vector2(-8, -8),
			Vector2(-2, -10), Vector2(10, -8), Vector2(16, -4),
			Vector2(14, 0), Vector2(8, 2)
		]),
		Color(0.28, 0.20, 0.12), 2.5, Vector2(18, 4))

	add_child(shoes)


# =========================================================
#  NPCs — Enhanced with more detail
# =========================================================

func _build_british_man() -> void:
	var result := _clickable("British Man", Vector2(210, 398),
			Vector2(70, 120), Vector2(0, -60))
	var area: ClickableObject = result[0]
	var visual: Node2D = result[1]
	area.z_index = 5

	_bm_visual = visual
	_bm_base_y = visual.position.y

	# chair / wooden bench (more detailed)
	_poly(visual,
		PackedVector2Array([
			Vector2(-32, 0), Vector2(32, 0), Vector2(36, -12),
			Vector2(36, -28), Vector2(-36, -28), Vector2(-36, -12)
		]),
		Color(0.42, 0.28, 0.14), 3.0)

	# chair legs visible below
	_line(visual,
		PackedVector2Array([Vector2(-30, 0), Vector2(-32, 8)]),
		Color(0.36, 0.24, 0.12), 3.0)
	_line(visual,
		PackedVector2Array([Vector2(30, 0), Vector2(32, 8)]),
		Color(0.36, 0.24, 0.12), 3.0)

	# chair cushion
	_poly(visual,
		PackedVector2Array([
			Vector2(-28, -26), Vector2(28, -26), Vector2(30, -30),
			Vector2(28, -36), Vector2(-28, -36), Vector2(-30, -30)
		]),
		Color(0.55, 0.15, 0.12), 2.0)

	# chair back (taller)
	_poly(visual,
		PackedVector2Array([
			Vector2(-34, -26), Vector2(-30, -26), Vector2(-30, -65),
			Vector2(-32, -70), Vector2(-36, -70), Vector2(-36, -30)
		]),
		Color(0.38, 0.24, 0.12), 2.5)

	# body — blue suit (broader shoulders)
	_poly(visual,
		PackedVector2Array([
			Vector2(-22, -34), Vector2(22, -34), Vector2(26, -42),
			Vector2(26, -68), Vector2(24, -78), Vector2(20, -82),
			Vector2(-20, -82), Vector2(-24, -78),
			Vector2(-26, -68), Vector2(-26, -42)
		]),
		Color(0.18, 0.28, 0.60), 3.5)

	# lapels (jacket detail)
	_line(visual,
		PackedVector2Array([
			Vector2(-10, -36), Vector2(-6, -60), Vector2(-4, -78)
		]),
		Color(0.14, 0.22, 0.50), 2.0)
	_line(visual,
		PackedVector2Array([
			Vector2(10, -36), Vector2(6, -60), Vector2(4, -78)
		]),
		Color(0.14, 0.22, 0.50), 2.0)

	# white shirt front (visible between lapels)
	_poly(visual,
		PackedVector2Array([
			Vector2(-6, -38), Vector2(6, -38), Vector2(4, -72), Vector2(-4, -72)
		]),
		Color(0.90, 0.87, 0.82), 0.0)

	# collar
	_poly(visual,
		PackedVector2Array([
			Vector2(-8, -76), Vector2(8, -76), Vector2(6, -82), Vector2(-6, -82)
		]),
		Color(0.92, 0.90, 0.85), 2.0)

	# tie/cravat
	_poly(visual,
		PackedVector2Array([
			Vector2(-3, -72), Vector2(3, -72), Vector2(2, -46),
			Vector2(0, -44), Vector2(-2, -46)
		]),
		Color(0.55, 0.15, 0.15), 0.0)

	# right arm (visible, resting on chair arm)
	_poly(visual,
		PackedVector2Array([
			Vector2(24, -74), Vector2(30, -74), Vector2(34, -56),
			Vector2(34, -38), Vector2(30, -34), Vector2(24, -38)
		]),
		Color(0.18, 0.28, 0.60), 2.5)

	# hand
	_poly(visual,
		PackedVector2Array([
			Vector2(-5, 0), Vector2(5, 0), Vector2(6, -4),
			Vector2(4, -8), Vector2(-4, -8), Vector2(-6, -4)
		]),
		Color(0.88, 0.73, 0.58), 2.0, Vector2(32, -32))

	# fingers detail
	_line(visual,
		PackedVector2Array([Vector2(30, -36), Vector2(32, -40)]),
		Color(0.70, 0.55, 0.42), 1.5)
	_line(visual,
		PackedVector2Array([Vector2(34, -36), Vector2(35, -40)]),
		Color(0.70, 0.55, 0.42), 1.5)

	# head (larger, more exaggerated chin)
	_poly(visual,
		PackedVector2Array([
			Vector2(-15, 2), Vector2(15, 2), Vector2(17, -6),
			Vector2(18, -14), Vector2(17, -24),
			Vector2(14, -33), Vector2(6, -38), Vector2(0, -40),
			Vector2(-6, -38), Vector2(-14, -33),
			Vector2(-17, -24), Vector2(-18, -14), Vector2(-17, -6)
		]),
		Color(0.88, 0.73, 0.58), 3.5, Vector2(0, -82))

	# prominent chin bump
	_poly(visual,
		PackedVector2Array([
			Vector2(-6, 0), Vector2(6, 0), Vector2(8, -4),
			Vector2(4, -8), Vector2(-4, -8), Vector2(-8, -4)
		]),
		Color(0.86, 0.71, 0.56), 2.0, Vector2(0, -78))

	# hair (parted, receding)
	_poly(visual,
		PackedVector2Array([
			Vector2(-16, 4), Vector2(-18, -4), Vector2(-16, -12),
			Vector2(-10, -18), Vector2(-2, -20), Vector2(6, -18),
			Vector2(14, -14), Vector2(17, -6), Vector2(16, 4),
			Vector2(12, 0), Vector2(6, -8), Vector2(0, -12),
			Vector2(-6, -10), Vector2(-12, -2)
		]),
		Color(0.45, 0.32, 0.15), 2.5, Vector2(0, -118))

	# left eye (wider, worried)
	_poly(visual,
		PackedVector2Array([
			Vector2(-4, -1), Vector2(-2, -4), Vector2(2, -4),
			Vector2(4, -1), Vector2(2, 2), Vector2(-2, 2)
		]),
		Color(0.95, 0.95, 0.95), 1.5, Vector2(-7, -98))
	# pupil
	_poly(visual,
		PackedVector2Array([
			Vector2(-1.5, -1.5), Vector2(1.5, -1.5),
			Vector2(1.5, 1.5), Vector2(-1.5, 1.5)
		]),
		Color.BLACK, 0.0, Vector2(-7, -98))

	# right eye
	_poly(visual,
		PackedVector2Array([
			Vector2(-4, -1), Vector2(-2, -4), Vector2(2, -4),
			Vector2(4, -1), Vector2(2, 2), Vector2(-2, 2)
		]),
		Color(0.95, 0.95, 0.95), 1.5, Vector2(7, -98))
	_poly(visual,
		PackedVector2Array([
			Vector2(-1.5, -1.5), Vector2(1.5, -1.5),
			Vector2(1.5, 1.5), Vector2(-1.5, 1.5)
		]),
		Color.BLACK, 0.0, Vector2(7, -98))

	# grimace mouth showing teeth
	_poly(visual,
		PackedVector2Array([
			Vector2(-8, -2), Vector2(8, -2), Vector2(8, 3), Vector2(-8, 3)
		]),
		Color(0.20, 0.05, 0.05), 2.0, Vector2(0, -86))
	# teeth
	_poly(visual,
		PackedVector2Array([
			Vector2(-6, -2), Vector2(6, -2), Vector2(6, 0), Vector2(-6, 0)
		]),
		Color(0.92, 0.90, 0.82), 0.0, Vector2(0, -86))

	# left eyebrow (raised — worried/surprised)
	_line(visual,
		PackedVector2Array([Vector2(-10, 3), Vector2(-5, -3), Vector2(0, -2)]),
		Color.BLACK, 2.5, Vector2(-2, -104))

	# right eyebrow
	_line(visual,
		PackedVector2Array([Vector2(0, -2), Vector2(5, -3), Vector2(10, 3)]),
		Color.BLACK, 2.5, Vector2(2, -104))

	# nose
	_poly(visual,
		PackedVector2Array([
			Vector2(-2, 0), Vector2(0, -6), Vector2(2, 0),
			Vector2(3, 3), Vector2(-3, 3)
		]),
		Color(0.86, 0.68, 0.52), 1.5, Vector2(0, -92))

	# ears
	_poly(visual,
		PackedVector2Array([
			Vector2(-2, -3), Vector2(-4, 0), Vector2(-4, 5),
			Vector2(-2, 7), Vector2(0, 5), Vector2(0, 0)
		]),
		Color(0.86, 0.70, 0.55), 1.5, Vector2(-17, -96))
	_poly(visual,
		PackedVector2Array([
			Vector2(0, 0), Vector2(0, 5), Vector2(2, 7),
			Vector2(4, 5), Vector2(4, 0), Vector2(2, -3)
		]),
		Color(0.86, 0.70, 0.55), 1.5, Vector2(17, -96))

	add_child(area)


func _build_old_professor() -> void:
	var result := _clickable("Old Professor", Vector2(695, 368),
			Vector2(65, 130), Vector2(0, -65))
	var area: ClickableObject = result[0]
	var visual: Node2D = result[1]
	area.z_index = 5

	_prof_visual = visual
	_prof_base_y = visual.position.y

	# body — dark green-brown coat (thinner, hunched)
	_poly(visual,
		PackedVector2Array([
			Vector2(-16, 0), Vector2(16, 0), Vector2(20, -22),
			Vector2(22, -54), Vector2(22, -70), Vector2(18, -78),
			Vector2(-18, -78), Vector2(-22, -70),
			Vector2(-22, -54), Vector2(-20, -22)
		]),
		Color(0.28, 0.34, 0.26), 3.5)

	# vest / front panel (purple-ish)
	_poly(visual,
		PackedVector2Array([
			Vector2(-7, -10), Vector2(7, -10), Vector2(8, -40),
			Vector2(7, -66), Vector2(-7, -66), Vector2(-8, -40)
		]),
		Color(0.40, 0.28, 0.44), 0.0)

	# vest buttons
	for by in [-25, -38, -52]:
		_poly(visual,
			PackedVector2Array([
				Vector2(-1.5, -1.5), Vector2(1.5, -1.5),
				Vector2(1.5, 1.5), Vector2(-1.5, 1.5)
			]),
			Color(0.65, 0.52, 0.20), 0.0, Vector2(0, by))

	# collar / shirt peek
	_poly(visual,
		PackedVector2Array([
			Vector2(-6, -72), Vector2(6, -72), Vector2(5, -78), Vector2(-5, -78)
		]),
		Color(0.88, 0.85, 0.78), 1.5)

	# left arm (more detail)
	_poly(visual,
		PackedVector2Array([
			Vector2(-22, -68), Vector2(-28, -68), Vector2(-32, -48),
			Vector2(-34, -32), Vector2(-32, -18), Vector2(-28, -14),
			Vector2(-22, -18), Vector2(-22, -48)
		]),
		Color(0.28, 0.34, 0.26), 2.5)

	# right arm (gesturing upward)
	_poly(visual,
		PackedVector2Array([
			Vector2(22, -68), Vector2(28, -68), Vector2(32, -50),
			Vector2(34, -36), Vector2(32, -20), Vector2(28, -14),
			Vector2(22, -18), Vector2(22, -50)
		]),
		Color(0.28, 0.34, 0.26), 2.5)

	# hands (with finger suggestion)
	_poly(visual,
		PackedVector2Array([
			Vector2(-6, 0), Vector2(6, 0), Vector2(7, -5),
			Vector2(4, -9), Vector2(-4, -9), Vector2(-7, -5)
		]),
		Color(0.82, 0.66, 0.50), 2.0, Vector2(-30, -13))
	_poly(visual,
		PackedVector2Array([
			Vector2(-6, 0), Vector2(6, 0), Vector2(7, -5),
			Vector2(4, -9), Vector2(-4, -9), Vector2(-7, -5)
		]),
		Color(0.82, 0.66, 0.50), 2.0, Vector2(30, -13))

	# finger lines on hands
	_line(visual,
		PackedVector2Array([Vector2(-32, -17), Vector2(-34, -20)]),
		Color(0.65, 0.50, 0.38), 1.0)
	_line(visual,
		PackedVector2Array([Vector2(32, -17), Vector2(34, -20)]),
		Color(0.65, 0.50, 0.38), 1.0)

	# head (slightly hunched forward)
	_poly(visual,
		PackedVector2Array([
			Vector2(-14, 0), Vector2(14, 0), Vector2(16, -8),
			Vector2(16, -22), Vector2(14, -30), Vector2(8, -36),
			Vector2(0, -38), Vector2(-8, -36), Vector2(-14, -30),
			Vector2(-16, -22), Vector2(-16, -8)
		]),
		Color(0.82, 0.66, 0.50), 3.5, Vector2(0, -78))

	# wild white hair (BIG, Einstein-style — much taller/wider)
	_poly(visual,
		PackedVector2Array([
			Vector2(-20, 6), Vector2(-24, -2), Vector2(-26, -12),
			Vector2(-22, -22), Vector2(-18, -30), Vector2(-12, -36),
			Vector2(-6, -40), Vector2(0, -42),
			Vector2(6, -40), Vector2(12, -36), Vector2(18, -30),
			Vector2(22, -22), Vector2(26, -12), Vector2(24, -2),
			Vector2(20, 6),
			# inner spiky tufts
			Vector2(14, -2), Vector2(16, -10),
			Vector2(12, -18), Vector2(8, -24),
			Vector2(4, -28), Vector2(0, -30),
			Vector2(-4, -28), Vector2(-8, -24),
			Vector2(-12, -18), Vector2(-16, -10), Vector2(-14, -2)
		]),
		Color(0.94, 0.94, 0.92), 2.5, Vector2(0, -112))

	# extra hair tufts (sticking out)
	_poly(visual,
		PackedVector2Array([
			Vector2(-24, -8), Vector2(-30, -14), Vector2(-28, -6)
		]),
		Color(0.92, 0.92, 0.90), 1.5, Vector2(0, -112))
	_poly(visual,
		PackedVector2Array([
			Vector2(24, -8), Vector2(30, -14), Vector2(28, -6)
		]),
		Color(0.92, 0.92, 0.90), 1.5, Vector2(0, -112))
	_poly(visual,
		PackedVector2Array([
			Vector2(-4, -40), Vector2(0, -48), Vector2(4, -40)
		]),
		Color(0.92, 0.92, 0.90), 1.5, Vector2(0, -112))

	# left eye (round, behind glasses)
	_poly(visual,
		PackedVector2Array([
			Vector2(-3, -1), Vector2(-2, -3), Vector2(2, -3),
			Vector2(3, -1), Vector2(2, 2), Vector2(-2, 2)
		]),
		Color(0.95, 0.95, 0.95), 1.0, Vector2(-6, -94))
	_poly(visual,
		PackedVector2Array([
			Vector2(-1.5, -1.5), Vector2(1.5, -1.5),
			Vector2(1.5, 1.5), Vector2(-1.5, 1.5)
		]),
		Color.BLACK, 0.0, Vector2(-6, -94))

	# right eye
	_poly(visual,
		PackedVector2Array([
			Vector2(-3, -1), Vector2(-2, -3), Vector2(2, -3),
			Vector2(3, -1), Vector2(2, 2), Vector2(-2, 2)
		]),
		Color(0.95, 0.95, 0.95), 1.0, Vector2(6, -94))
	_poly(visual,
		PackedVector2Array([
			Vector2(-1.5, -1.5), Vector2(1.5, -1.5),
			Vector2(1.5, 1.5), Vector2(-1.5, 1.5)
		]),
		Color.BLACK, 0.0, Vector2(6, -94))

	# glasses (round wire frames)
	_line(visual,
		PackedVector2Array([
			Vector2(-10, -3), Vector2(-10, 3), Vector2(-6, 5),
			Vector2(-2, 3), Vector2(-2, -3), Vector2(-6, -5), Vector2(-10, -3)
		]),
		Color(0.28, 0.28, 0.28), 1.8, Vector2(0, -93))
	_line(visual,
		PackedVector2Array([
			Vector2(2, -3), Vector2(2, 3), Vector2(6, 5),
			Vector2(10, 3), Vector2(10, -3), Vector2(6, -5), Vector2(2, -3)
		]),
		Color(0.28, 0.28, 0.28), 1.8, Vector2(0, -93))
	# bridge
	_line(visual,
		PackedVector2Array([Vector2(-2, -1), Vector2(2, -1)]),
		Color(0.28, 0.28, 0.28), 1.5, Vector2(0, -93))
	# earpieces
	_line(visual,
		PackedVector2Array([Vector2(-10, -2), Vector2(-14, -2), Vector2(-16, 0)]),
		Color(0.28, 0.28, 0.28), 1.2, Vector2(0, -93))
	_line(visual,
		PackedVector2Array([Vector2(10, -2), Vector2(14, -2), Vector2(16, 0)]),
		Color(0.28, 0.28, 0.28), 1.2, Vector2(0, -93))

	# nose (bulbous)
	_poly(visual,
		PackedVector2Array([
			Vector2(-2, 0), Vector2(0, -5), Vector2(2, 0),
			Vector2(3, 4), Vector2(0, 6), Vector2(-3, 4)
		]),
		Color(0.80, 0.62, 0.46), 1.5, Vector2(0, -86))

	# excited smile (wider, upturned)
	_line(visual,
		PackedVector2Array([
			Vector2(-7, 0), Vector2(-4, 3), Vector2(-1, 5),
			Vector2(1, 5), Vector2(4, 3), Vector2(7, 0)
		]),
		Color.BLACK, 2.5, Vector2(0, -82))

	# bushy eyebrows (white, thick, wild)
	_line(visual,
		PackedVector2Array([
			Vector2(-12, 2), Vector2(-8, -2), Vector2(-4, -3), Vector2(0, -1)
		]),
		Color(0.88, 0.88, 0.86), 3.5, Vector2(0, -100))
	_line(visual,
		PackedVector2Array([
			Vector2(0, -1), Vector2(4, -3), Vector2(8, -2), Vector2(12, 2)
		]),
		Color(0.88, 0.88, 0.86), 3.5, Vector2(0, -100))

	# ear (left)
	_poly(visual,
		PackedVector2Array([
			Vector2(-2, -3), Vector2(-4, 0), Vector2(-3, 4),
			Vector2(0, 5), Vector2(1, 2)
		]),
		Color(0.80, 0.62, 0.46), 1.5, Vector2(-16, -90))

	add_child(area)


# =========================================================
#  SHADOW POOLS — dark ellipses under objects/characters
# =========================================================

func _build_shadow_pools() -> void:
	var shadow_data := [
		# [position, x_radius, y_radius, alpha]
		[Vector2(210, 402), 32.0, 8.0, 0.20],   # British Man
		[Vector2(695, 372), 28.0, 7.0, 0.18],   # Professor
		[Vector2(72, 394), 18.0, 5.0, 0.15],    # Stone Bust
		[Vector2(865, 424), 30.0, 7.0, 0.15],   # Display Case
		[Vector2(790, 152), 35.0, 5.0, 0.08],   # Painting (wall shadow)
	]

	for sd in shadow_data:
		var pool := Polygon2D.new()
		pool.position = sd[0]
		pool.z_index = 0
		var pts := PackedVector2Array()
		var rx: float = sd[1]
		var ry: float = sd[2]
		for i in range(16):
			var a := float(i) / 16.0 * TAU
			pts.append(Vector2(cos(a) * rx, sin(a) * ry))
		pool.polygon = pts
		pool.color = Color(0.02, 0.01, 0.0, sd[3])
		add_child(pool)


# =========================================================
#  FOREGROUND ELEMENTS — depth silhouettes at screen edges
# =========================================================

func _build_foreground_elements() -> void:
	# Left foreground — dark furniture edge
	var left_fg := Node2D.new()
	left_fg.name = "LeftForeground"
	left_fg.z_index = 12

	_poly(left_fg,
		PackedVector2Array([
			Vector2(-15, 540), Vector2(-15, 340), Vector2(-5, 320),
			Vector2(5, 330), Vector2(15, 360), Vector2(25, 400),
			Vector2(30, 460), Vector2(25, 540)
		]),
		Color(0.06, 0.03, 0.01), 0.0)

	# decorative curve on edge
	_line(left_fg,
		PackedVector2Array([
			Vector2(10, 340), Vector2(18, 370), Vector2(22, 420),
			Vector2(20, 470)
		]),
		Color(0.12, 0.06, 0.03), 2.5)

	add_child(left_fg)

	# Right foreground — edge of display case / furniture
	var right_fg := Node2D.new()
	right_fg.name = "RightForeground"
	right_fg.z_index = 12

	_poly(right_fg,
		PackedVector2Array([
			Vector2(960, 540), Vector2(960, 360), Vector2(950, 340),
			Vector2(940, 350), Vector2(932, 380), Vector2(928, 430),
			Vector2(930, 490), Vector2(935, 540)
		]),
		Color(0.06, 0.03, 0.01), 0.0)

	_line(right_fg,
		PackedVector2Array([
			Vector2(945, 350), Vector2(938, 390), Vector2(935, 450),
			Vector2(938, 510)
		]),
		Color(0.12, 0.06, 0.03), 2.5)

	add_child(right_fg)

	# Bottom foreground — floor edge / baseboard
	var bottom_fg := Node2D.new()
	bottom_fg.name = "BottomForeground"
	bottom_fg.z_index = 11

	_poly(bottom_fg,
		PackedVector2Array([
			Vector2(0, 540), Vector2(0, 520), Vector2(120, 515),
			Vector2(300, 525), Vector2(480, 528),
			Vector2(660, 525), Vector2(840, 515),
			Vector2(960, 520), Vector2(960, 540)
		]),
		Color(0.08, 0.04, 0.02), 0.0)

	add_child(bottom_fg)


# =========================================================
#  PARTICLES
# =========================================================

func _build_dust_motes() -> void:
	# Door light dust motes
	var p := CPUParticles2D.new()
	p.name = "DoorDustMotes"
	p.position = Vector2(480, 240)
	p.z_index = 8
	p.amount = 22
	p.lifetime = 6.0
	p.randomness = 0.7
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(75, 100)
	p.direction = Vector2(0.15, -1)
	p.spread = 30.0
	p.gravity = Vector2(0, -3)
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 5.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 2.2
	p.color = Color(1.0, 0.94, 0.78, 0.20)
	add_child(p)

	# Window area dust (left)
	var lw := CPUParticles2D.new()
	lw.name = "LeftWindowDust"
	lw.position = Vector2(134, 180)
	lw.z_index = 8
	lw.amount = 8
	lw.lifetime = 5.0
	lw.randomness = 0.8
	lw.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	lw.emission_rect_extents = Vector2(30, 40)
	lw.direction = Vector2(0.3, -1)
	lw.spread = 40.0
	lw.gravity = Vector2(0, -2)
	lw.initial_velocity_min = 1.0
	lw.initial_velocity_max = 3.5
	lw.scale_amount_min = 0.6
	lw.scale_amount_max = 1.5
	lw.color = Color(1.0, 0.92, 0.72, 0.15)
	add_child(lw)

	# Window area dust (right)
	var rw := CPUParticles2D.new()
	rw.name = "RightWindowDust"
	rw.position = Vector2(810, 186)
	rw.z_index = 8
	rw.amount = 8
	rw.lifetime = 5.0
	rw.randomness = 0.8
	rw.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rw.emission_rect_extents = Vector2(30, 40)
	rw.direction = Vector2(-0.3, -1)
	rw.spread = 40.0
	rw.gravity = Vector2(0, -2)
	rw.initial_velocity_min = 1.0
	rw.initial_velocity_max = 3.5
	rw.scale_amount_min = 0.6
	rw.scale_amount_max = 1.5
	rw.color = Color(1.0, 0.92, 0.72, 0.15)
	add_child(rw)


# =========================================================
#  ANIMATION
# =========================================================

func _animate() -> void:
	# Candle flame flicker
	if _flame:
		var sx := 1.0 + sin(_time * 5.0) * 0.12 + sin(_time * 7.3) * 0.06
		var sy := 1.0 + sin(_time * 4.0) * 0.14 + cos(_time * 6.1) * 0.07
		_flame.scale = Vector2(sx, sy)
		_flame.modulate.a = 0.85 + sin(_time * 8.0) * 0.15
	if _flame_inner:
		_flame_inner.scale = _flame.scale * 0.95
		_flame_inner.modulate.a = 0.90 + cos(_time * 9.0) * 0.10

	# Candle glow pulses subtly
	if _candle_glow:
		var ga := 0.06 + sin(_time * 3.0) * 0.015 + sin(_time * 5.5) * 0.008
		_candle_glow.color.a = ga

	# Flag wave
	if _flag_node:
		_flag_node.rotation = sin(_time * 1.5) * 0.04

	# British Man subtle breathing
	if _bm_visual:
		_bm_visual.position.y = _bm_base_y + sin(_time * 1.0) * 1.2

	# Professor gentle sway (more animated — excited)
	if _prof_visual:
		_prof_visual.position.y = _prof_base_y + sin(_time * 1.2) * 1.0
		_prof_visual.rotation = sin(_time * 0.6) * 0.015
