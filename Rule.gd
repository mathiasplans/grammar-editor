extends Node3D
class_name Rule

var meshes = {}
var split_tree = null
var split_root = null
var poly_to_treeitem = {}
var leaf_polys = {}

var poly_obj = {}

var lhs = null
var lhs_poly = null

var index = -1
var compiled = false

var anchors = {}

const simulacrumMat = preload("res://mats/simulacrum.tres")

# Persistant:
# * split_tree
# * split_root
# * poly_to_treeitem
# * leaf_polys -> meshes
# * lhs
# * lhs_poly
# * index
# * anchors (keys)

func _init(_index):
	self.index = _index
	
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
			
			mat.albedo_color.a = 1
			mat.transparency = false
			
	else:
		for m in self.meshes[poly]:
			var mat = m.get_active_material(0)
			
			mat.albedo_color.a = t
			mat.transparency = true
			
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

func set_meshes(poly, mesh_instances):
	self.meshes[poly] = mesh_instances
	
	var pobj = self.get_pobj(poly)
	for meshi in mesh_instances:
		pobj.add_child(meshi)
	
	if self.leaf_polys.keys().size() == 0:
		self.set_leafness(poly)
		
		# Add the anchor visualization
		var new_anchor = Anchor.new(0, 1, poly, 0, 0.15, 0.76)
		
		# Add copies of the meshes to the background
		self._add_simulacrum(mesh_instances)
		
		pobj.add_child(new_anchor)
	
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
