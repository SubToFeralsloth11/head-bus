class_name Models
extends RefCounted
## Low-poly model library. Every model is built once from MeshKit parts and cached.
## Vehicles face -Z (front at -Z), stand on y = 0 and are centred on the origin.

const GLASS := Color("1d2b3a")
const TYRE := Color("1b1b1d")
const HUB := Color("b8bcc2")
const TRIM := Color("3a3d42")
const HEAD := Color("fff6c8")
const TAIL := Color("ff2a2a")
const AMBER := Color("ffa51f")
const WHITE := Color("f2f2ee")
const BRAND := Color("1f9d55")
const CAR_COLOURS: Array[Color] = [
	Color("c0392b"), Color("2e6fc1"), Color("ecf0f1"), Color("9aa4ad"), Color("2b2d31"),
	Color("2f8f4e"), Color("e67e22"), Color("16a3a3"), Color("7d3c98"),
]
## Hitbox half extents (x, z) per vehicle type.
const CAR_SIZE := {
	"sedan": Vector2(0.92, 2.22), "hatch": Vector2(0.88, 1.97), "suv": Vector2(1.0, 2.37),
	"van": Vector2(1.0, 2.52), "truck": Vector2(1.27, 5.2), "taxi": Vector2(0.92, 2.22),
}

static var _cache := {}


static func mesh(key: String) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = _build(key)
	return _cache[key]


static func _build(key: String) -> ArrayMesh:
	var k := MeshKit.new()
	var parts := key.split(":")
	match parts[0]:
		"bus": _bus(k)
		"car": _car(k, parts[1], CAR_COLOURS[int(parts[2])])
		"broken": _broken(k, CAR_COLOURS[int(parts[1])])
		"cone": _cone(k)
		"triangle": _triangle(k)
		"barrier": _barrier(k)
		"pothole": _pothole(k)
		"coin": _coin(k)
		"pine": _pine(k)
		"tree": _tree(k, int(parts[1]))
		"bush": _bush(k)
		"house": _house(k, int(parts[1]))
		"lamp": _lamp(k)
		"fence": _fence(k)
		"hill": _hill(k, int(parts[1]))
		"road": _road(k)
		"busstop": _bus_stop(k)
		"sign": _speed_sign(k)
		"station": _station(k)
		_: push_error("Unknown model " + key)
	return k.build()


# --- Vehicles ---------------------------------------------------------------

static func _bus(k: MeshKit) -> void:
	var red := Color("d62828")
	var cream := Color("f1e3c4")
	k.box(Vector3(0, 2.125, 0), Vector3(2.5, 3.55, 10.5), red)
	# White roof with rounded shoulders and hatches: the view you see most.
	k.hull(Vector3(0, 3.9, 0), Vector2(2.5, 10.5), Vector2(2.2, 10.2), 0.14, WHITE)
	k.box(Vector3(0, 4.08, -2.5), Vector3(0.9, 0.08, 0.9), Color("cfcfcf"))
	k.box(Vector3(0, 4.08, 2.5), Vector3(0.9, 0.08, 0.9), Color("cfcfcf"))
	# Window bands on both decks, broken up by pillars.
	k.box(Vector3(0, 1.5, 0.15), Vector3(2.54, 0.95, 9.6), GLASS)
	k.box(Vector3(0, 2.95, 0.0), Vector3(2.54, 0.95, 10.0), GLASS)
	for i in 8:
		var z := -4.2 + i * 1.25
		k.box(Vector3(0, 1.5, z), Vector3(2.58, 0.97, 0.14), red)
		k.box(Vector3(0, 2.95, z), Vector3(2.58, 0.97, 0.14), red)
	k.box(Vector3(0, 2.22, 0), Vector3(2.53, 0.12, 10.52), cream)
	# Front: windscreens, destination blind, lights, bumper.
	k.box(Vector3(0, 1.55, -5.27), Vector3(2.2, 1.05, 0.06), GLASS)
	k.box(Vector3(0, 2.95, -5.27), Vector3(2.2, 0.9, 0.06), GLASS)
	k.box(Vector3(0, 2.25, -5.29), Vector3(1.6, 0.26, 0.05), Color("ffb703"), Vector3.ZERO, true)
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * 0.92, 0.78, -5.28), Vector3(0.32, 0.22, 0.06), HEAD, Vector3.ZERO, true)
		k.box(Vector3(s * 0.95, 0.85, 5.28), Vector3(0.22, 0.4, 0.06), TAIL, Vector3.ZERO, true)
		# Mirrors on arms.
		k.box(Vector3(s * 1.4, 2.0, -5.05), Vector3(0.35, 0.05, 0.05), TRIM)
		k.box(Vector3(s * 1.58, 1.85, -5.05), Vector3(0.08, 0.35, 0.18), TRIM)
	k.box(Vector3(0, 0.45, -5.3), Vector3(2.56, 0.26, 0.18), TRIM)
	k.box(Vector3(0, 0.45, 5.3), Vector3(2.56, 0.26, 0.18), TRIM)
	k.box(Vector3(0, 2.95, 5.27), Vector3(2.0, 0.8, 0.06), GLASS)
	k.box(Vector3(0, 1.55, 5.27), Vector3(1.9, 0.75, 0.06), GLASS)
	for i in 4:
		k.box(Vector3(0, 0.75 + i * 0.09, 5.28), Vector3(1.2, 0.04, 0.04), TRIM)
	k.box(Vector3(0, 2.22, 5.29), Vector3(1.3, 0.22, 0.04), Color("ffb703"), Vector3.ZERO, true)
	k.box(Vector3(0, 0.62, 5.29), Vector3(0.55, 0.14, 0.03), WHITE)
	# Kerb-side door.
	k.box(Vector3(-1.27, 1.25, -4.2), Vector3(0.06, 1.75, 1.0), Color("2a3a4a"))
	for z in [-3.6, 3.2]:
		for s in [-1.0, 1.0]:
			k.wheel(Vector3(s * 1.12, 0.52, z), 0.52, 0.36, TYRE, HUB)


static func _car(k: MeshKit, type: String, body: Color) -> void:
	match type:
		"sedan", "taxi":
			if type == "taxi":
				body = Color("f4c430")
			k.box(Vector3(0, 0.62, 0), Vector3(1.8, 0.56, 4.4), body)
			k.hull(Vector3(0, 0.9, 0.25), Vector2(1.66, 2.5), Vector2(1.4, 1.5), 0.55, GLASS, 0.15)
			k.box(Vector3(0, 1.47, 0.4), Vector3(1.42, 0.05, 1.5), body)
			_car_ends(k, 2.2, 0.72, 1.8)
			for z in [-1.35, 1.35]:
				for s in [-1.0, 1.0]:
					k.wheel(Vector3(s * 0.84, 0.34, z), 0.34, 0.24, TYRE, HUB)
			for s in [-1.0, 1.0]:
				k.box(Vector3(s * 0.95, 1.0, -0.6), Vector3(0.16, 0.1, 0.08), body)
			if type == "taxi":
				k.box(Vector3(0, 1.6, 0.4), Vector3(0.7, 0.2, 0.26), Color("fff3a0"), Vector3.ZERO, true)
				k.box(Vector3(0, 0.66, 0), Vector3(1.82, 0.1, 2.6), Color("222222"))
		"hatch":
			k.box(Vector3(0, 0.6, 0), Vector3(1.72, 0.54, 3.9), body)
			k.hull(Vector3(0, 0.87, 0.35), Vector2(1.6, 2.3), Vector2(1.4, 1.7), 0.55, GLASS, 0.25)
			k.box(Vector3(0, 1.44, 0.6), Vector3(1.42, 0.05, 1.7), body)
			_car_ends(k, 1.95, 0.7, 1.72)
			for z in [-1.2, 1.2]:
				for s in [-1.0, 1.0]:
					k.wheel(Vector3(s * 0.8, 0.32, z), 0.32, 0.22, TYRE, HUB)
		"suv":
			k.box(Vector3(0, 0.85, 0), Vector3(1.95, 0.8, 4.7), body)
			k.hull(Vector3(0, 1.25, 0.3), Vector2(1.8, 3.0), Vector2(1.66, 2.5), 0.62, GLASS, 0.15)
			k.box(Vector3(0, 1.9, 0.45), Vector3(1.68, 0.06, 2.5), body)
			for s in [-1.0, 1.0]:
				k.box(Vector3(s * 0.7, 1.97, 0.45), Vector3(0.06, 0.08, 2.2), TRIM)
			_car_ends(k, 2.35, 1.0, 1.95)
			k.cyl(Vector3(0, 1.0, 2.43), 0.36, 0.36, 0.2, TYRE, 10, Vector3(90, 0, 0))
			for z in [-1.5, 1.5]:
				for s in [-1.0, 1.0]:
					k.wheel(Vector3(s * 0.92, 0.42, z), 0.42, 0.28, TYRE, HUB)
		"van":
			k.box(Vector3(0, 1.3, 0.65), Vector3(1.95, 1.8, 3.7), body)
			k.box(Vector3(0, 0.8, -1.85), Vector3(1.95, 0.8, 1.3), body)
			k.hull(Vector3(0, 1.2, -1.45), Vector2(1.9, 1.5), Vector2(1.9, 0.6), 1.0, GLASS, 0.45)
			k.box(Vector3(0, 1.72, -0.75), Vector3(1.97, 0.6, 0.9), GLASS)
			k.box(Vector3(0, 1.3, 2.51), Vector3(0.04, 1.6, 0.03), TRIM)
			_car_ends(k, 2.5, 0.85, 1.95)
			for z in [-1.6, 1.7]:
				for s in [-1.0, 1.0]:
					k.wheel(Vector3(s * 0.9, 0.38, z), 0.38, 0.26, TYRE, HUB)
		"truck":
			var cab := body
			var box_col := WHITE if body.v < 0.85 else Color("d9dde2")
			k.box(Vector3(0, 1.7, -4.1), Vector3(2.4, 2.4, 2.2), cab)
			k.hull(Vector3(0, 2.9, -3.7), Vector2(2.3, 1.4), Vector2(2.3, 0.7), 0.5, cab, 0.35)
			k.box(Vector3(0, 2.15, -5.22), Vector3(2.2, 0.95, 0.06), GLASS)
			k.box(Vector3(0, 2.2, -4.45), Vector3(2.42, 0.7, 0.9), GLASS)
			k.box(Vector3(0, 1.0, -5.22), Vector3(1.6, 0.6, 0.06), TRIM)
			k.box(Vector3(0, 2.2, 1.4), Vector3(2.5, 2.9, 7.6), box_col)
			k.box(Vector3(0, 1.1, 1.4), Vector3(2.52, 0.3, 7.62), cab)
			k.box(Vector3(0, 0.6, 0.1), Vector3(1.6, 0.35, 9.8), TRIM)
			for s in [-1.0, 1.0]:
				k.box(Vector3(s * 0.95, 0.85, -5.23), Vector3(0.36, 0.2, 0.05), HEAD, Vector3.ZERO, true)
				k.box(Vector3(s * 1.0, 1.0, 5.21), Vector3(0.3, 0.2, 0.05), TAIL, Vector3.ZERO, true)
				k.box(Vector3(s * 1.35, 2.3, -5.0), Vector3(0.08, 0.5, 0.2), TRIM)
			k.box(Vector3(0, 0.5, -5.28), Vector3(2.45, 0.25, 0.14), TRIM)
			for z in [-4.0, 3.3, 4.4]:
				for s in [-1.0, 1.0]:
					k.wheel(Vector3(s * 1.07, 0.5, z), 0.5, 0.36, TYRE, HUB)


## Bumpers, lights, grille and number plate for a car `half_len` long.
static func _car_ends(k: MeshKit, half_len: float, light_y: float, width: float) -> void:
	k.box(Vector3(0, light_y - 0.3, -half_len - 0.02), Vector3(width + 0.02, 0.22, 0.12), TRIM)
	k.box(Vector3(0, light_y - 0.3, half_len + 0.02), Vector3(width + 0.02, 0.22, 0.12), TRIM)
	k.box(Vector3(0, light_y - 0.08, -half_len - 0.01), Vector3(width * 0.38, 0.14, 0.04), TRIM)
	k.box(Vector3(0, light_y - 0.18, half_len + 0.05), Vector3(0.5, 0.12, 0.03), WHITE)
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * width * 0.33, light_y, -half_len - 0.01), Vector3(0.36, 0.14, 0.05), HEAD, Vector3.ZERO, true)
		k.box(Vector3(s * width * 0.34, light_y + 0.03, half_len + 0.01), Vector3(0.34, 0.14, 0.05), TAIL, Vector3.ZERO, true)


## A broken-down saloon: bonnet up and hazard lights on.
static func _broken(k: MeshKit, body: Color) -> void:
	_car(k, "sedan", body)
	k.box(Vector3(0, 1.4, -1.35), Vector3(1.6, 0.05, 1.2), body, Vector3(55, 0, 0))
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * 0.88, 0.75, -2.22), Vector3(0.12, 0.12, 0.06), AMBER, Vector3.ZERO, true)
		k.box(Vector3(s * 0.88, 0.75, 2.22), Vector3(0.12, 0.12, 0.06), AMBER, Vector3.ZERO, true)


# --- Road obstacles ---------------------------------------------------------

static func _cone(k: MeshKit) -> void:
	k.box(Vector3(0, 0.03, 0), Vector3(0.5, 0.06, 0.5), Color("2b2b2b"))
	k.cyl(Vector3(0, 0.41, 0), 0.03, 0.2, 0.7, Color("ff6b1a"), 10)
	k.cyl(Vector3(0, 0.42, 0), 0.101, 0.135, 0.14, WHITE, 10)


static func _triangle(k: MeshKit) -> void:
	k.prism(Vector3(0, 0.36, 0), Vector3(0.75, 0.65, 0.05), Color("e01e1e"), Vector3(-12, 0, 0))
	k.prism(Vector3(0, 0.33, 0.012), Vector3(0.44, 0.38, 0.05), WHITE, Vector3(-12, 0, 0))
	k.box(Vector3(0, 0.02, 0.1), Vector3(0.5, 0.04, 0.3), Color("333333"))


static func _barrier(k: MeshKit) -> void:
	for i in 6:
		var col := Color("e01e1e") if i % 2 == 0 else WHITE
		k.box(Vector3(-1.25 + i * 0.5, 0.95, 0), Vector3(0.5, 0.32, 0.08), col)
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * 1.3, 0.55, -0.15), Vector3(0.1, 1.15, 0.08), Color("444444"), Vector3(-14, 0, 0))
		k.box(Vector3(s * 1.3, 0.55, 0.15), Vector3(0.1, 1.15, 0.08), Color("444444"), Vector3(14, 0, 0))
		k.cyl(Vector3(s * 1.3, 1.25, 0), 0.1, 0.1, 0.18, AMBER, 8, Vector3.ZERO, true)
	# "Road works" sign on top.
	k.box(Vector3(0, 1.35, 0), Vector3(0.08, 0.5, 0.06), Color("444444"))
	k.prism(Vector3(0, 1.95, 0.0), Vector3(1.0, 0.85, 0.06), Color("e01e1e"))
	k.prism(Vector3(0, 1.9, 0.02), Vector3(0.62, 0.52, 0.06), WHITE)
	k.box(Vector3(0, 1.82, 0.05), Vector3(0.1, 0.22, 0.02), Color("111111"))


static func _pothole(k: MeshKit) -> void:
	k.cyl(Vector3(0, 0.012, 0), 0.85, 0.85, 0.02, Color("5c5a55"), 9, Vector3.ZERO)
	k.add_mesh(_disc(0.68), MeshKit.xf(Vector3(0, 0.025, 0), Vector3.ZERO, Vector3(1, 1, 1.25)), Color("121212"))


static func _disc(r: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = 0.02
	m.radial_segments = 9
	m.rings = 1
	return m


static func _coin(k: MeshKit) -> void:
	k.cyl(Vector3.ZERO, 0.45, 0.45, 0.1, Color("e8a317"), 12, Vector3(90, 0, 0))
	k.cyl(Vector3.ZERO, 0.3, 0.3, 0.13, Color("ffd34d"), 12, Vector3(90, 0, 0), true)


# --- Scenery ----------------------------------------------------------------

static func _pine(k: MeshKit) -> void:
	k.cyl(Vector3(0, 0.5, 0), 0.15, 0.2, 1.0, Color("6b4423"), 6)
	k.cyl(Vector3(0, 1.8, 0), 0.0, 1.4, 2.0, Color("2d6a3e"), 7)
	k.cyl(Vector3(0, 2.9, 0), 0.0, 1.1, 1.7, Color("357a48"), 7)
	k.cyl(Vector3(0, 3.85, 0), 0.0, 0.75, 1.4, Color("3d8a52"), 7)


static func _tree(k: MeshKit, v: int) -> void:
	var greens := [Color("4f9a3a"), Color("6aae3e"), Color("3f8a3c")]
	var g: Color = greens[v % greens.size()]
	k.cyl(Vector3(0, 0.9, 0), 0.17, 0.25, 1.8, Color("7a5230"), 6)
	k.ball(Vector3(0, 2.7, 0), 1.35, g, Vector3(1, 0.9, 1))
	k.ball(Vector3(0.65, 3.3, 0.2), 0.95, g.lightened(0.12))
	k.ball(Vector3(-0.55, 3.25, -0.35), 0.9, g.darkened(0.1))


static func _bush(k: MeshKit) -> void:
	k.ball(Vector3(0, 0.45, 0), 0.7, Color("4e8f3a"), Vector3(1.2, 0.8, 1))
	k.ball(Vector3(0.6, 0.4, 0.2), 0.5, Color("5ea044"))


## House with its front door facing +X.
static func _house(k: MeshKit, v: int) -> void:
	var walls := [Color("f3ead8"), Color("b5523b"), Color("cfe0e8"), Color("efe3a8")]
	var roofs := [Color("8e3b2e"), Color("4a4f57"), Color("6b3a2a"), Color("5a5e66")]
	k.box(Vector3(0, 1.5, 0), Vector3(5.5, 3.0, 6.0), walls[v % 4])
	k.prism(Vector3(0, 3.9, 0), Vector3(6.2, 1.8, 6.6), roofs[v % 4])
	k.box(Vector3(1.2, 4.1, -1.8), Vector3(0.6, 1.4, 0.6), Color("8a4b3a"))
	k.box(Vector3(2.77, 1.0, 0), Vector3(0.06, 2.0, 1.0), Color("3c5a8a") if v % 2 == 0 else Color("2f6b3f"))
	for z in [-1.9, 1.9]:
		k.box(Vector3(2.77, 1.7, z), Vector3(0.06, 1.1, 1.3), WHITE)
		k.box(Vector3(2.79, 1.7, z), Vector3(0.06, 0.9, 1.1), GLASS)
	k.box(Vector3(3.6, 0.03, 0), Vector3(1.6, 0.06, 1.1), Color("a9a49a"))


## Street lamp whose arm reaches toward +X.
static func _lamp(k: MeshKit) -> void:
	k.cyl(Vector3(0, 3.0, 0), 0.07, 0.1, 6.0, Color("5b6168"), 6)
	k.box(Vector3(0.7, 5.95, 0), Vector3(1.5, 0.08, 0.08), Color("5b6168"))
	k.box(Vector3(1.4, 5.88, 0), Vector3(0.6, 0.16, 0.28), Color("4a4f55"))
	k.box(Vector3(1.4, 5.79, 0), Vector3(0.5, 0.03, 0.22), Color("fff3b0"), Vector3.ZERO, true)


static func _fence(k: MeshKit) -> void:
	var wood := Color("9b6b43")
	for i in 5:
		k.box(Vector3(0, 0.5, -4.0 + i * 2.0), Vector3(0.12, 1.0, 0.12), wood)
	k.box(Vector3(0, 0.45, 0), Vector3(0.06, 0.1, 8.0), wood)
	k.box(Vector3(0, 0.82, 0), Vector3(0.06, 0.1, 8.0), wood)


static func _hill(k: MeshKit, v: int) -> void:
	var cols := [Color("6f9f55"), Color("5d8f4c"), Color("7aa860")]
	k.cyl(Vector3(0, 7, 0), 4.0, 32.0, 14.0, cols[v % 3], 7)
	k.cyl(Vector3(18, 4, 10), 2.0, 18.0, 8.0, cols[(v + 1) % 3], 6)


## One 40 m stretch of two-lane road with markings.
static func _road(k: MeshKit) -> void:
	k.box(Vector3(0, -0.01, 0), Vector3(7.0, 0.04, 40.0), Color("3b3e44"))
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * 3.85, -0.015, 0), Vector3(0.7, 0.04, 40.0), Color("9a978e"))
		k.box(Vector3(s * 3.25, 0.012, 0), Vector3(0.14, 0.02, 40.0), WHITE)
	for i in 8:
		k.box(Vector3(0, 0.012, -17.5 + i * 5.0), Vector3(0.14, 0.02, 2.6), WHITE)


## Bus shelter whose open side faces +X.
static func _bus_stop(k: MeshKit) -> void:
	var frame := Color("2f3a46")
	for z in [-1.6, 1.6]:
		for x in [-0.6, 0.6]:
			k.box(Vector3(x, 1.2, z), Vector3(0.08, 2.4, 0.08), frame)
	k.box(Vector3(0, 2.45, 0), Vector3(1.6, 0.1, 3.6), Color("c0392b"))
	k.box(Vector3(-0.6, 1.3, 0), Vector3(0.04, 1.8, 3.2), Color("9fc8dd"))
	k.box(Vector3(-0.3, 0.5, 0), Vector3(0.4, 0.08, 2.4), Color("8a5a3a"))
	k.cyl(Vector3(1.0, 1.4, 2.2), 0.05, 0.05, 2.8, frame, 6)
	k.cyl(Vector3(1.0, 2.75, 2.2), 0.32, 0.32, 0.05, Color("c0392b"), 12, Vector3(0, 0, 90))
	k.cyl(Vector3(1.0, 2.75, 2.2), 0.22, 0.22, 0.06, WHITE, 12, Vector3(0, 0, 90))


## Round speed-limit sign facing +Z (toward an approaching driver).
static func _speed_sign(k: MeshKit) -> void:
	k.cyl(Vector3(0, 1.1, 0), 0.05, 0.05, 2.2, Color("8d949b"), 6)
	k.cyl(Vector3(0, 2.4, 0), 0.45, 0.45, 0.05, Color("d62828"), 14, Vector3(90, 0, 0))
	k.cyl(Vector3(0, 2.4, 0.01), 0.34, 0.34, 0.06, WHITE, 14, Vector3(90, 0, 0))


## Petrol station on the left of the road. z = 0 is the start of the entry slip
## road; the station runs to z = -120. Pumps sit beside the lane, the shop beyond.
static func _station(k: MeshKit) -> void:
	var tarmac := Color("34373d")
	var concrete := Color("9d9a92")
	k.flat_quad(Vector3(-3.4, 0.016, 0), Vector3(-9.0, 0.016, -20), Vector3(-9.0, 0.016, -100), Vector3(-3.4, 0.016, -120), tarmac)
	k.box(Vector3(-15.0, 0.02, -60), Vector3(12.0, 0.04, 64.0), concrete)
	for i in 12:
		k.box(Vector3(-3.6, 0.03, -24.0 - i * 6.5), Vector3(0.14, 0.02, 3.0), WHITE)
	for z in [-46.0, -60.0, -74.0]:
		k.box(Vector3(-10.3, 0.12, z), Vector3(1.3, 0.24, 4.5), Color("d8d2c0"))
		for dz in [-1.0, 1.0]:
			var pz: float = z + dz
			k.box(Vector3(-10.3, 1.05, pz), Vector3(0.7, 1.6, 0.9), WHITE)
			k.box(Vector3(-10.3, 1.95, pz), Vector3(0.72, 0.3, 0.92), BRAND)
			k.box(Vector3(-9.93, 1.45, pz), Vector3(0.03, 0.32, 0.55), Color("bff7ff"), Vector3.ZERO, true)
			k.box(Vector3(-9.9, 0.9, pz + 0.3), Vector3(0.05, 0.9, 0.05), Color("111111"))
			k.box(Vector3(-9.88, 1.15, pz - 0.25), Vector3(0.08, 0.25, 0.12), Color("222222"))
	for z in [-48.5, -71.5]:
		k.cyl(Vector3(-10.3, 2.7, z), 0.22, 0.22, 5.4, Color("e6e6e6"), 8)
	# Canopy covers the pumps only, so it never hides the bus from the chase camera.
	k.box(Vector3(-10.4, 5.6, -60), Vector3(3.8, 0.7, 46.0), WHITE)
	k.box(Vector3(-10.4, 5.6, -60), Vector3(3.9, 0.34, 46.1), BRAND)
	k.box(Vector3(-10.4, 5.23, -60), Vector3(3.4, 0.04, 44.0), Color("fffbe8"), Vector3.ZERO, true)
	# Shop with a glass front facing the road.
	k.box(Vector3(-18.0, 1.9, -60), Vector3(7.0, 3.8, 16.0), Color("ede8dc"))
	k.box(Vector3(-17.8, 3.9, -60), Vector3(7.8, 0.25, 17.0), Color("5a5e66"))
	k.box(Vector3(-14.47, 1.35, -60), Vector3(0.06, 2.3, 12.0), GLASS)
	k.box(Vector3(-14.45, 1.15, -60), Vector3(0.08, 1.9, 1.6), Color("9fd0e6"))
	k.box(Vector3(-14.4, 3.35, -60), Vector3(0.12, 0.7, 9.0), BRAND)
	# Tall price board facing approaching traffic.
	k.box(Vector3(-11.5, 3.0, -8), Vector3(0.35, 6.0, 0.35), Color("8d949b"))
	k.box(Vector3(-11.5, 6.4, -8), Vector3(2.4, 3.2, 0.35), BRAND)
	for i in 3:
		k.box(Vector3(-11.5, 6.9 - i * 0.65, -7.81), Vector3(1.9, 0.48, 0.04), Color("fff3c4"), Vector3.ZERO, true)
