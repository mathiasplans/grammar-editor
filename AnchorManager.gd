extends Node
class_name AnchorManager
signal polyhedron_reordered(poly, new_order)

const anchorMat = preload("res://mats/anchor.tres")

class AnchorNode:
	var center
	var left
	var right

	var snode
	
	func _init(_center,_snode=null):
		self.center = _center
		self.snode = _snode
		
		self.left = null
		self.right = null
		
class AnchorMeta:
	var poly
	var sym
	var anchor_nodes = []
	var edge_to_node = {}
	
	var active
	
	var snode
	
	var mat
	
	func _init(_poly,_sym,a,b):
		self.poly = _poly
		self.sym = _sym
		
		self.snode = Node3D.new()
		self.mat = anchorMat.duplicate()
		
		# Create all possible anchors
		for face_i in self.poly.faces.size():
			var face = self.poly.faces[face_i]
			var face_size = face.size()
			var face_anchors = []
			for fi in face_size:
				var vi = face[fi]
				var next_vi = face[(fi + 1) % face_size]
				
				# Create a copy of the polyhedron
				var copy_poly = self.poly.create_copy()
				copy_poly.order_by_anchor(vi, next_vi)
				
				# Check if this topology can have the symbol
				if self.sym.can_be_assigned_to(copy_poly):
					var new_anchor = Anchor.new(vi, next_vi, self.poly, face_i, self.mat)
					self.snode.add_child(new_anchor)
					new_anchor.visible = false
					face_anchors.push_back(new_anchor)
					
			# Connect the face anchors if possible
			var face_anchor_nodes = []
			var nr_of_face_anchors = face_anchors.size()
			for anchor in face_anchors:
				var new_node = AnchorNode.new(anchor, snode)
				face_anchor_nodes.push_back(new_node)
				self.edge_to_node[[anchor.ai, anchor.bi]] = new_node
			
			var prev_anchor
			var curr_anchor
			for prev_i in nr_of_face_anchors:
				var curr_i = (prev_i + 1) % nr_of_face_anchors
				
				prev_anchor = face_anchors[prev_i]
				curr_anchor = face_anchors[curr_i]
				
				var prev_node = face_anchor_nodes[prev_i]
				var curr_node = face_anchor_nodes[curr_i]
				
				if prev_anchor.bi == curr_anchor.ai:
					prev_node.right = curr_node
					curr_node.left = prev_node
					
			# Add to the all anchors
			self.anchor_nodes.append_array(face_anchor_nodes)
			
		# Set the active
		self.active = self.edge_to_node[[a, b]]
		self.active.center.visible = true
			
	func _apply_anchor_order():
		var anchor_order = self.poly.order_by_anchor(self.active.center.ai, self.active.center.bi)
		var inverse_anchor_order = Polyhedron._invert_anchor_order(anchor_order)
		
		# Apply the order to all the anchors
		for anchor_node in self.anchor_nodes:
			anchor_node.center.apply_inverse_anchor_order(inverse_anchor_order)
			
		# Change the keys
		var new_map = {}
		for key in self.edge_to_node.keys():
			var new_key = [inverse_anchor_order[key[0]], inverse_anchor_order[key[1]]]
			new_map[new_key] = self.edge_to_node[key]
			
		self.edge_to_node = new_map
		
		return anchor_order
		
	func _set_active(anchor_node):
		var is_sel = self.active.center.selected
		self.active.center.deselect()
		self.active.center.visible = false
		self.active = anchor_node
		self.active.center.visible = true
		if is_sel:
			self.active.center.select()
		
	func move_face(face_i):
		# Attempt to move anchor to the face
		var face = self.poly.faces[face_i]
		
		var face_size = face.size()
		for fi in face_size:
			var vi = face[fi]
			var next_vi = face[(fi + 1) % face_size]
			
			var anchor_node = self.edge_to_node[[vi, next_vi]]
			
			if anchor_node != null:
				self._set_active(anchor_node)
				return self._apply_anchor_order()

		return null
				
	func rotate_left():
		if self.active.left != null:
			self._set_active(self.active.left)
			return self._apply_anchor_order()
			
		return null
			
	func rotate_right():
		if self.active.right != null:
			self._set_active(self.active.right)
			return self._apply_anchor_order()
			
		return null
		
	func select():
		self.active.center.select()
		
	func deselect():
		self.active.center.deselect()
		
var polymeta = {}

func add_poly(poly, sym):
	var new_am = AnchorMeta.new(poly, sym, 0, 1)
	self.polymeta[poly] = new_am
	return new_am.snode
	
func move_face(poly, face_i):
	var new_order = self.polymeta[poly].move_face(face_i)
	if new_order != null:
		self.polyhedron_reordered.emit(poly, new_order)
	return new_order

func rotate_left(poly):
	var new_order = self.polymeta[poly].rotate_left()
	if new_order != null:
		self.polyhedron_reordered.emit(poly, new_order)
	return new_order
	
func rotate_right(poly):
	var new_order = self.polymeta[poly].rotate_right()
	if new_order != null:
		self.polyhedron_reordered.emit(poly, new_order)
	return new_order
	
func select(poly):
	self.polymeta[poly].select()
	
func deselect(poly):
	self.polymeta[poly].deselect()
	
func remove_poly(poly):
	if self.polymeta.has(poly):
		for node in self.polymeta[poly].anchor_nodes:
			node.center.queue_free()
			
		self.polymeta[poly].snode.queue_free()
		self.polymeta.erase(poly)
		
func get_anchor(poly):
	return self.polymeta[poly].snode
