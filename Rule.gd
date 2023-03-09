extends Node
class_name Rule

var cuts = []
var meshes = {}
var split_tree = null
var split_root = null
var poly_to_treeitem = {}
var leaf_polys = {}

var lhs = null
var lhs_poly = null

func set_meshes(poly, mesh_instances):
	self.meshes[poly] = mesh_instances
	
func get_meshes(poly):
	return self.meshes[poly]
	
func erase_meshes(poly):
	if poly != null:
		# Free the old meshes
		for m in self.meshes[poly]:
			m.queue_free()
			
		self.meshes.erase(poly)
	
func get_treeitem(poly):
	return self.poly_to_treeitem[poly]
	
func set_treeitem(poly, item):
	self.poly_to_treeitem[poly] = item
	
func set_leafness(poly):
	self.leaf_polys[poly] = true
	
func remove_leafness(poly):
	self.leaf_polys.erase(poly)
	
func add_cut(cut):
	self.cuts.push_back(cut)
	
func get_leaf_polys():
	return self.leaf_polys.keys()


