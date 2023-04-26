extends MeshInstance3D
class_name Anchor


const anchor_tex = preload("res://icons/anchor.png")
const anchorMat = preload("res://mats/anchor.tres")

const unselected_col = Color(0, 0, 0, 1)
const selected_col = Color(0, 1, 0, 1)
const outline_col = Color(0, 0, 0, 0.25)

var ab_len = 0.2
var ac_len

var ai
var bi
var face_i
var poly
var selected

func _init(_ai, _bi, _poly, _face_i, mat, _ab_len=0.2):
	self.face_i = _face_i
	self.poly = _poly
	self.ab_len = _ab_len
	self.ac_len = self.ab_len * 768 / 634
	
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
	
	var anchor_mesh = Geom.convexhull_to_mesh([v1, v2, v3, v4])
	
	if mat is ShaderMaterial:
		mat.set_shader_parameter("color", self.unselected_col)
	
	self.mesh = anchor_mesh
	self.material_override = mat

func apply_inverse_anchor_order(inverse_anchor_order):
	self.ai = inverse_anchor_order[self.ai]
	self.bi = inverse_anchor_order[self.bi]
	
	self.face_i = self.poly.directed_to_face[[ai, bi]]
	
func select():
	self.material_override.set_shader_parameter("color", self.selected_col)
	self.material_override.set_shader_parameter("outline", self.outline_col)
	self.selected = true
	
func deselect():
	self.material_override.set_shader_parameter("color", self.unselected_col)
	self.material_override.set_shader_parameter("outline", Color(0, 0, 0, 0))
	self.selected = false
