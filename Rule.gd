extends Node3D
class_name Rule

var meshes = {}
var split_tree = null
var split_root = null
var poly_to_treeitem = {}
var leaf_polys = {}

var lhs = null
var lhs_poly = null

var index = -1
var compiled = false

var anchors = {}

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

func set_meshes(poly, mesh_instances):
	self.meshes[poly] = mesh_instances
	
	if self.leaf_polys.keys().size() == 0:
		self.set_leafness(poly)
		
		# Add the anchor visualization
		var new_anchor = Anchor.new(0, 1, poly, 0, 0.15, 0.76)
		
		self.add_child(new_anchor)
	
func get_meshes(poly):
	return self.meshes[poly]
	
func erase_meshes(poly):
	if poly != null:
		# Free the old meshes
		for m in self.meshes[poly]:
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
	return true
	
func remove_anchor(poly):
	return self.anchors.erase(poly)
	
func get_anchor(poly):
	if self.anchors.has(poly):
		return self.anchors[poly]
		
	return null

func get_polyhedrons():
	return self.meshes.keys()
