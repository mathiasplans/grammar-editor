extends MeshInstance
class_name Anchor

const ab_len = 0.2
const ac_len = ab_len * 768 / 634
const anchor_tex = preload("res://icons/anchor.png")
const unselected_col = Color(0, 0, 0, 1)
const selected_col = Color(0, 1, 0, 1)

var ai
var bi
var face_i
var poly
var selected

func _init(_ai, _bi, _poly, _face_i):
	self.face_i = _face_i
	self.poly = _poly
	
	# Calculate normal
	var na = self.poly.vertices[self.poly.faces[_face_i][0]]
	var nb = self.poly.vertices[self.poly.faces[_face_i][1]]
	var nc = self.poly.vertices[self.poly.faces[_face_i][2]]
	var normal = Geom.calculate_normal_from_points(na, nb, nc)
	
	self.ai = _ai
	self.bi = _bi
	var a = self.poly.vertices[self.ai]
	var b = self.poly.vertices[self.bi]
	
	var ab_raw = b - a
	var ab = self.ab_len * ab_raw.normalized()
	var ac = self.ac_len * ab.cross(normal).normalized()
	
	var to_mid = (ab_raw - ab) / 2
	
	var v1 = a + 0.02 * (normal) + to_mid
	var v2 = v1 + ab
	var v3 = v2 + ac
	var v4 = v3 - ab
	
	var mesh = Geom.convexhull_to_mesh([v1, v2, v3, v4])
	
	var mat = SpatialMaterial.new()
	mat.albedo_color = unselected_col
	mat.albedo_texture = anchor_tex
	mat.flags_transparent = true
	mat.params_cull_mode = SpatialMaterial.CULL_DISABLED
	
	self.mesh = mesh
	self.material_override = mat

func apply_inverse_anchor_order(inverse_anchor_order):
	self.ai = inverse_anchor_order[self.ai]
	self.bi = inverse_anchor_order[self.bi]
	
	self.face_i = self.poly.directed_to_face[[ai, bi]]
	
func select():
	self.material_override.albedo_color = selected_col
	self.selected = true
	
func deselect():
	self.material_override.albedo_color = unselected_col
	self.selected = false
