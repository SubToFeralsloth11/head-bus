class_name MeshKit
extends RefCounted
## Builds one flat-shaded, vertex-coloured ArrayMesh from transformed parts.
## Two surfaces: lit ("solid") and unshaded ("glow", for lamps and signs), so a
## whole model is at most two draw calls.

static var solid_mat: StandardMaterial3D
static var glow_mat: StandardMaterial3D
## Sign of (b - a) x (c - a) . normal for the engine's front faces, learnt from a
## primitive so hand-made faces wind the same way.
static var _front_sign := 0.0

var _sv := PackedVector3Array()
var _sn := PackedVector3Array()
var _sc := PackedColorArray()
var _gv := PackedVector3Array()
var _gn := PackedVector3Array()
var _gc := PackedColorArray()


func _init() -> void:
	if solid_mat:
		return
	solid_mat = StandardMaterial3D.new()
	solid_mat.vertex_color_use_as_albedo = true
	solid_mat.vertex_color_is_srgb = true
	solid_mat.roughness = 0.85
	glow_mat = StandardMaterial3D.new()
	glow_mat.vertex_color_use_as_albedo = true
	glow_mat.vertex_color_is_srgb = true
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var arr := BoxMesh.new().get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var cr := (v[idx[1]] - v[idx[0]]).cross(v[idx[2]] - v[idx[0]])
	_front_sign = signf(cr.dot(n[idx[0]]))


static func xf(pos: Vector3, rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot_deg * (PI / 180.0)).scaled(scale), pos)


func _tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color, glow: bool) -> void:
	if glow:
		_gv.append_array([a, b, c])
		_gn.append_array([n, n, n])
		_gc.append_array([col, col, col])
	else:
		_sv.append_array([a, b, c])
		_sn.append_array([n, n, n])
		_sc.append_array([col, col, col])


## Adds a primitive mesh; every face gets its own normal for the faceted look.
func add_mesh(mesh: PrimitiveMesh, t: Transform3D, col: Color, glow := false) -> void:
	var arr := mesh.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var nb := t.basis.inverse().transposed()
	var count := idx.size() if not idx.is_empty() else v.size()
	for k in range(0, count, 3):
		var i0 := idx[k] if not idx.is_empty() else k
		var i1 := idx[k + 1] if not idx.is_empty() else k + 1
		var i2 := idx[k + 2] if not idx.is_empty() else k + 2
		var a := t * v[i0]
		var b := t * v[i1]
		var c := t * v[i2]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			continue
		n = n.normalized()
		if n.dot(nb * (nr[i0] + nr[i1] + nr[i2])) < 0.0:
			n = -n
		_tri(a, b, c, n, col, glow)


func box(pos: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO, glow := false) -> void:
	var m := BoxMesh.new()
	m.size = size
	add_mesh(m, xf(pos, rot), col, glow)


## Cylinder or cone (r_top = 0) centred on pos, axis along local Y.
func cyl(pos: Vector3, r_top: float, r_bot: float, h: float, col: Color, segs := 8, rot := Vector3.ZERO, glow := false) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	add_mesh(m, xf(pos, rot), col, glow)


func ball(pos: Vector3, r: float, col: Color, scale := Vector3.ONE, segs := 7, rings := 4) -> void:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = segs
	m.rings = rings
	add_mesh(m, xf(pos, Vector3.ZERO, scale), col)


## Triangular prism: triangle in XY (apex on top), extruded along Z.
func prism(pos: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO, glow := false) -> void:
	var m := PrismMesh.new()
	m.size = size
	add_mesh(m, xf(pos, rot), col, glow)


## Wheel with its axle along X; the hub faces outward on the side of pos.x.
func wheel(pos: Vector3, r: float, w: float, tyre: Color, hub: Color) -> void:
	cyl(pos, r, r, w, tyre, 10, Vector3(0, 0, 90))
	var side := 1.0 if pos.x >= 0.0 else -1.0
	cyl(pos + Vector3(side * w * 0.5, 0, 0), r * 0.55, r * 0.55, 0.04, hub, 8, Vector3(0, 0, 90))


## Tapered block: bottom rectangle `bot` (x, z) at pos.y, top rectangle `top`
## shifted by top_dz along Z, `h` high. Used for cabins and sloped windscreens.
func hull(pos: Vector3, bot: Vector2, top: Vector2, h: float, col: Color, top_dz := 0.0, glow := false) -> void:
	var p: Array[Vector3] = [
		pos + Vector3(-bot.x / 2, 0, -bot.y / 2), pos + Vector3(bot.x / 2, 0, -bot.y / 2),
		pos + Vector3(bot.x / 2, 0, bot.y / 2), pos + Vector3(-bot.x / 2, 0, bot.y / 2),
		pos + Vector3(-top.x / 2, h, -top.y / 2 + top_dz), pos + Vector3(top.x / 2, h, -top.y / 2 + top_dz),
		pos + Vector3(top.x / 2, h, top.y / 2 + top_dz), pos + Vector3(-top.x / 2, h, top.y / 2 + top_dz),
	]
	var centre := pos + Vector3(0, h / 2, top_dz / 2)
	for f in [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]:
		_tri_out(p[f[0]], p[f[1]], p[f[2]], centre, col, glow)
		_tri_out(p[f[0]], p[f[2]], p[f[3]], centre, col, glow)


## Flat quad lying on the ground, facing up.
func flat_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	var below := (a + b + c + d) / 4.0 - Vector3.UP
	_tri_out(a, b, c, below, col, false)
	_tri_out(a, c, d, below, col, false)


func _tri_out(a: Vector3, b: Vector3, c: Vector3, inside: Vector3, col: Color, glow: bool) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-12:
		return
	var n := cr.normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		n = -n
	if signf(cr.dot(n)) == _front_sign:
		_tri(a, b, c, n, col, glow)
	else:
		_tri(a, c, b, n, col, glow)


func build() -> ArrayMesh:
	var m := ArrayMesh.new()
	if not _sv.is_empty():
		_surface(m, _sv, _sn, _sc, solid_mat)
	if not _gv.is_empty():
		_surface(m, _gv, _gn, _gc, glow_mat)
	return m


static func _surface(m: ArrayMesh, v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, mat: Material) -> void:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(m.get_surface_count() - 1, mat)
