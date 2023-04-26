extends Node3D
class_name Rule

var meshes = {}
var split_tree = null
var split_root = null
var poly_to_treeitem = {}
var leaf_polys = {}
var colors = {}

var poly_obj = {}

var from_shape = null
var from_shape_poly = null

var index = -1
var compiled = false

var anchors = {}

const simulacrumMat = preload("res://mats/simulacrum.tres")
const contouredMat = preload("res://mats/contouredface.tres")
const anchorMat = preload("res://mats/anchor.tres")

const contouredShader = preload("res://shaders/contouredface.gdshader")
const contouredAlphaShader = preload("res://shaders/contouredface_alpha.gdshader")

# Persistant:
# * split_tree
# * split_root
# * poly_to_treeitem
# * leaf_polys -> meshes
# * lhs
# * lhs_poly
# * index
# * anchors (keys)

func _init(shape, _index):
	self.from_shape = shape
	self.index = _index
	
	self.from_shape_poly = self.from_shape.get_polyhedron()
	
func is_empty():
	return self.meshes.size() == 0
	
func get_pobj(poly):
	var obj
	if poly in self.poly_obj:
		obj = self.poly_obj[poly]
		
	else:
		obj = Node3D.new()
		self.add_child(obj)
		self.poly_obj[poly] = obj
		
	return obj
	
func set_visibility(poly, vis):
	var pobj = self.get_pobj(poly)
	pobj.visible = vis
		
func set_transparency(poly, t):
	if t > 0.99:
		for m in self.meshes[poly]:
			var mat = m.get_active_material(0)
			
			mat.shader = contouredShader
			mat.set_shader_parameter("albedo_color", self.colors[poly])
			
	else:
		for m in self.meshes[poly]:
			var mat = m.get_active_material(0)
			
			mat.shader = contouredAlphaShader
			mat.set_shader_parameter("transparency", t)
			mat.set_shader_parameter("albedo_color", self.colors[poly])
			
func set_collision(poly, c):
	if c:
		for m in self.meshes[poly]:
			m.enable_collision()
			
	else:
		for m in self.meshes[poly]:
			m.disable_collision()

func _add_simulacrum(mesh_instances):
	for mi in mesh_instances:
		var mesh = mi.mesh.duplicate()
		
		var newmi = MeshInstance3D.new()
		newmi.mesh = mesh
		newmi.material_override = simulacrumMat
		
		self.add_child(newmi)

func set_meshes(poly, mesh_instances, color: Color):
	self.meshes[poly] = mesh_instances
	
	var newMat = self.contouredMat.duplicate()
	newMat.set_shader_parameter("albedo_color", color)
	
	self.colors[poly] = color
	
	var pobj = self.get_pobj(poly)
	for meshi in mesh_instances:
		pobj.add_child(meshi)
		meshi.set_mat(newMat)
	
	if self.leaf_polys.keys().size() == 0:
		self.set_leafness(poly)
		
		# Add copies of the meshes to the background
		self._add_simulacrum(mesh_instances)
		
func add_reference_anchor(anchor):
	self.add_child(anchor)
	
func get_meshes(poly):
	return self.meshes[poly]
	
func erase_meshes(poly):
	if poly != null:
		# Free the old meshes
		for m in self.meshes[poly]:
			m.material_override = null
			m.queue_free()
			
		self.meshes.erase(poly)
		
func get_all_meshes():
	var all_meshes = []
	for key in self.meshes.keys():
		all_meshes.append_array(self.meshes[key])
		
	return all_meshes
	
func get_visible_meshes(treemanager):
	var all_meshes = []
	for key in self.meshes.keys():
		var item = self.poly_to_treeitem[key]
		
		if treemanager.is_visible(item):
			all_meshes.append_array(self.meshes[key])
			
	return all_meshes
	
func get_treeitem(poly):
	return self.poly_to_treeitem[poly]
	
func set_treeitem(poly, item):
	self.poly_to_treeitem[poly] = item
	
func set_leafness(poly):
	self.leaf_polys[poly] = true
	
func remove_leafness(poly):
	self.leaf_polys.erase(poly)
	
func is_leaf(poly):
	return self.leaf_polys.has(poly)
	
func get_leaf_polys():
	return self.leaf_polys.keys()
	
func add_anchor(poly, anchor):
	if self.anchors.has(poly) and self.anchors[poly] == anchor:
		return false
		
	self.anchors[poly] = anchor
	
	var pobj = self.get_pobj(poly)
	pobj.add_child(anchor)
	
	return true
	
func remove_anchor(poly):
	var anchor = self.anchors[poly]
	var pobj = self.get_pobj(poly)
	pobj.remove_child(anchor)
	return self.anchors.erase(poly)
	
func get_anchor(poly):
	if self.anchors.has(poly):
		return self.anchors[poly]
		
	return null

func get_polyhedrons():
	return self.meshes.keys()
	
func get_vertices(_transform):
	var verts = []
	for poly in self.get_polyhedrons():
		for vert in poly.vertices:
			var new_vert = _transform * vert
			verts.append(new_vert)
			
	return verts
	
func get_corners(_transform):
	var verts = []
	for vert in from_shape_poly.vertices:
		var new_vert = _transform * vert
		verts.append(new_vert)
		
	return verts
	
func get_symbol():
	return self.from_shape.symbol
