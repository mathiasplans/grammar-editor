extends Spatial

# Declare member variables here.
var mouse_down = false
var cuts = []
var meshes = {}
var split_root = null
var poly_to_treeitem = {}
var leaf_polys = {}
var symbol_gen = null
const ROT_SPEED = 0.01

onready var split_tree = $"../../../../Right/Tree"
onready var compile_button = $"../../../TopPanel/GridContainer/CompileButton"
onready var test_grammar = $"../../../TopPanel/GridContainer/TestGrammar"
onready var apply_rule = $"../../../TopPanel/GridContainer/ApplyRule"
onready var global_cut = $"../../../TopPanel/GridContainer/GlobalCut"
onready var selector = $Editor/Selector
onready var anchor_manager = $Editor/AnchorManager

const button_visible_tex = preload("res://icons/GuiVisibilityVisible.svg")
const button_hidden_tex = preload("res://icons/GuiVisibilityHidden.svg")
const button_epsilon = preload("res://icons/Greek_lc_epsilon.png")
const button_epsilon_not = preload("res://icons/Greek_lc_epsilon_dis.png")
const shape_icon = preload("res://icons/aneZtd-cube-cut-out.png")
const compiled_icon = preload("res://icons/compiled.png")
const not_compiled_icon = preload("res://icons/unsynced.png")
const scissors_icon = preload("res://icons/scissors.png")
const button_xray_tex = preload("res://icons/GuiVisibilityXray.svg")

enum {NODE_POLY, NODE_SPLIT}
enum {TREE_TEXT, TREE_SYMBOL, tree_nr_of_cols, TREE_META = TREE_TEXT, TREE_BUTTONS = TREE_SYMBOL}
enum {BUTTON_EPSILON, BUTTON_HIDE, tree_nr_of_buttons}
enum {VIS_HIDDEN, VIS_XRAY, VIS_VISIBLE, VIS_amount}

var hidden_to_tex = {VIS_HIDDEN: button_hidden_tex, VIS_VISIBLE: button_visible_tex, VIS_XRAY: button_xray_tex}
var epsilon_to_tex = {true: button_epsilon, false: button_epsilon_not}

func _hidden_button_change(treeitem, tm):
	treeitem.set_button(TREE_BUTTONS, BUTTON_HIDE, hidden_to_tex[tm.hidden])

func _create_face_instances(poly):
	var mesh_instances = poly.get_face_objects()
	
	for mesh_instance in mesh_instances:
		# Add collision
		var mesh_area = Area.new()
		var mesh_colshape = CollisionShape.new()
		var colshape = ConcavePolygonShape.new()
		
		var polygons = mesh_instance.mesh.get_faces()
		colshape.set_faces(polygons)
		mesh_colshape.set_shape(colshape)
		
		# Set up the hierarchy
		mesh_area.add_child(mesh_colshape)
		mesh_instance.add_child(mesh_area)
		
		# Name the mesh area
		mesh_area.name = "Area"
		mesh_colshape.name = "Colshape"
		
		# Set needed attributes
		mesh_area.input_ray_pickable = true
		
	return mesh_instances

func _add_random_color(mesh_instances):
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for mesh_instance in mesh_instances:
		# Set color
		var col = Color(rng.randf_range(0.5, 1.0), rng.randf_range(0.5, 1.0), rng.randf_range(0.7, 1.0), 1.0)
		
		var mat = SpatialMaterial.new()
		mat.albedo_color = col
			
		mesh_instance.set_surface_material(0, mat)

func _mount_poly(poly):
	var mesh_instances = self._create_face_instances(poly)
	self._add_random_color(mesh_instances)
	
	for mesh_instance in mesh_instances:
		mesh_instance.connect("create_cut", self, "_on_create_cut")
		$Editor.add_child(mesh_instance)
		
	return mesh_instances

func poly_to_meshes(poly):
	var mesh_instances = self._mount_poly(poly)
	self.meshes[poly] = mesh_instances
	
class TreeMeta:
	var poly = null
	var split = null
	var parent_split = null
	var hidden = VIS_VISIBLE
	var epsilon = false
	var leaf = true
	var other_hidden = VIS_VISIBLE
	
	var parent_indices = []
	var constructions = []
	
	var rotations = []
	
static func _treeitem_setup(item, metadata, text):
	item.add_button(TREE_BUTTONS, button_epsilon_not, BUTTON_EPSILON)
	item.add_button(TREE_BUTTONS, button_visible_tex, BUTTON_HIDE)
	
	item.set_metadata(TREE_META, metadata)
	item.set_text(TREE_TEXT, text)
	
	item.set_icon(0, shape_icon)
	
	item.set_editable(TREE_SYMBOL, true)
	
# Called when the node enters the scene tree for the first time.
func _ready():
	self.symbol_gen = GrammarSymbolMaker.new()
	
	# Create a selector object. Has to be created before adding any shapes
	self.selector.connect("polyhedron_selected", self, "_on_polyhedron_selected")
	self.selector.connect("polyhedron_deselected", self, "_on_polyhedron_deselect")
	
	# Create a cube for now
	var cube = Cube.new(0.4)
	cube.original = true
	self.poly_to_meshes(cube)
	self.leaf_polys[cube] = true
	
	# Symbol handling
	cube.order_by_anchor(0, 1)
	var seed_sym = "seed"
	var sym = self.symbol_gen.from_polyhedron(cube, seed_sym, false)
	cube.symbol = sym
	
	self.split_tree.columns = tree_nr_of_cols
	
	self.split_root = self.split_tree.create_item()
	var tm = TreeMeta.new()
	tm.poly = cube
	
	for i in sym.nr_of_vertices:
		tm.parent_indices.push_back(i)

	self.poly_to_treeitem[cube] = self.split_root

	_treeitem_setup(self.split_root, tm, "A")
	self.split_root.set_editable(TREE_SYMBOL, false)
	self.split_root.set_text(TREE_SYMBOL, seed_sym)
	
	# Connect the signals
	self.split_tree.connect("button_pressed", self, "_on_tree_button")
	self.split_tree.connect("item_selected", self, "_on_tree_selected")
	self.split_tree.connect("item_edited", self, "_on_item_edited")
	
	self.compile_button.connect("pressed", self, "_on_compile_button_press")
	self.test_grammar.connect("pressed", self, "_on_test_grammar_press")
	self.apply_rule.connect("pressed", self, "_on_apply_rule_press")
	
	# Anchor manager
	self.anchor_manager.connect("polyhedron_reordered", self, "_on_poly_reorder")
	
func _treeitem_set_visibility(item):
	var tm = item.get_metadata(TREE_META)
	if tm.leaf:
		var state = tm.hidden
		for m in self.meshes[tm.poly]:
			var t = false
			if (state == VIS_HIDDEN) or tm.epsilon:
				m.visible = false
				
			elif state == VIS_XRAY:
				# Make transparent
				t = true
				
				m.visible = true
				
			elif state == VIS_VISIBLE:
				m.visible = true
			
			var mat = m.get_active_material(0)	
			
			if t:
				mat.albedo_color.a = 0.2
				mat.flags_transparent = true
				m.disable_collision()
			
			else:
				mat.albedo_color.a = 1
				mat.flags_transparent = false
				m.enable_collision()

func _treeitem_visible(item, vis):
	var tm = item.get_metadata(TREE_META)
	tm.hidden = vis
	
	# Change the icon
	self._hidden_button_change(item, tm)
	
	if not tm.epsilon:	
		_treeitem_set_visibility(item)

		var child = item.get_children()
		while child != null:
			_treeitem_visible(child, vis)
			child = child.get_next()
			
func _treeitem_epsilonize(item, eps):
	var tm = item.get_metadata(TREE_META)
	tm.epsilon = eps
	
	_treeitem_set_visibility(item)
	
	item.set_button(TREE_BUTTONS, BUTTON_EPSILON, epsilon_to_tex[tm.epsilon])

func _on_tree_button(item, column, id):
	var tm = item.get_metadata(TREE_META)
	if column == TREE_BUTTONS:
		if id == BUTTON_HIDE:
			if Input.is_physical_key_pressed(KEY_SHIFT):
				if tm.other_hidden == VIS_XRAY:
					tm.other_hidden = VIS_VISIBLE
				
				else:
					tm.other_hidden = VIS_XRAY
				
				var parent = item.get_parent()
				
				while parent != null:
					var child = parent.get_children()
					while child != null:
						if child != item:
							self._treeitem_visible(child, tm.other_hidden)
							
						child = child.get_next()
							
					item = parent
					parent = parent.get_parent()

			else:
				self._treeitem_visible(item, (tm.hidden + 1) % VIS_amount)
			
		elif id == BUTTON_EPSILON:
			self._treeitem_epsilonize(item, not tm.epsilon)

func _on_tree_selected():
	var selected_item = self.split_tree.get_selected()
	var meta = selected_item.get_metadata(TREE_META)
	
	# Get one of the faces
	var face = self.meshes[meta.poly][0]
	self.selector.select_poly(face)
	
func _on_polyhedron_selected(poly):
	var item = self.poly_to_treeitem[poly]
	item.select(TREE_TEXT)
	
func _on_polyhedron_deselect(poly):
	var item = self.poly_to_treeitem[poly]
	item.deselect(TREE_TEXT)
	
# Called when an event happens
func _input(event):
	if event is InputEventMouseButton:
		mouse_down = event.is_pressed()
		
	if event is InputEventMouseMotion:
		if mouse_down:
			self.rotate(Vector3.UP, event.relative.x * ROT_SPEED)
			self.rotate(Vector3.RIGHT, event.relative.y * ROT_SPEED)
		
	if event is InputEventKey:
		if event.pressed and event.scancode == KEY_Z and event.control:
			if cuts.size() > 0:
				var cut = cuts.pop_back()
				cut.queue_free()

# When a cut has been made, add the cutting plane
# mesh as a child and connect the 'cut_complete' signal
func _on_create_cut(cut_plane):
	self.cuts.push_back(cut_plane)
	$Editor.add_child(cut_plane)
	cut_plane.connect("cut_complete", self, "_on_cut_complete")

func _add_child_polyhedron(cut, parent_treeitem, cut_plane, text, sym=null):
	var poly = cut[0]
	var translation = cut[1]
	var construction = cut[2]
	
	# Set the symbol
	poly.symbol = sym
	
	# Add new meshes
	self.poly_to_meshes(poly)
	
	# Add the new polyhedrons and the split to the tree
	var new_treeitem = self.split_tree.create_item(parent_treeitem)
	
	var tm = TreeMeta.new()
	tm.poly = poly
	tm.parent_split = cut_plane
	tm.parent_indices = translation
	tm.constructions = construction
	
	_treeitem_setup(new_treeitem, tm, text)
	
	self.poly_to_treeitem[poly] = new_treeitem
	
	# Add to the leaf
	self.leaf_polys[poly] = true
	
func _retire_poly(poly):
	if poly != null:
		# Free the old meshes
		for m in self.meshes[poly]:
			m.queue_free()
			
		self.meshes.erase(poly)
	
func _cut_poly(cut_plane, poly):
	var cutdata = poly.cut(cut_plane.point(), cut_plane.normal)
	
	# No cut was made, do nothing
	if cutdata.size() == 1:
		# Flag the cut_plane to delete itself
		cut_plane.delete = true
		return

	# Free the old meshes
	self._retire_poly(poly)
	
	# Get the node in the split tree
	var parent_treeitem = self.poly_to_treeitem[poly]
	
	# Register the split
	var tm = parent_treeitem.get_metadata(TREE_META)
	tm.leaf = false
	
	if cut_plane.poly == poly:
		tm.split = cut_plane
	
	# Change the icon
	parent_treeitem.set_icon(TREE_TEXT, scissors_icon)
	
	# Remove the epsilon button
	parent_treeitem.set_button_disabled(TREE_BUTTONS, BUTTON_EPSILON, true)
	
	# Handle new polyhedrons
	var cut1 = cutdata[0]
	var cut2 = cutdata[1]
	
	self._add_child_polyhedron(cut1, parent_treeitem, cut_plane, "B")
	self._add_child_polyhedron(cut2, parent_treeitem, cut_plane, "C")

	# Deactivate
	self.leaf_polys.erase(poly)

# On the cut completion, cut the polygon
func _on_cut_complete(cut_plane):
	if self.global_cut.pressed:
		var leaves = self.leaf_polys.keys().duplicate()
		for leaf in leaves:
			self._cut_poly(cut_plane, leaf)		
		
	else:
		self._cut_poly(cut_plane, cut_plane.poly)
	
	# Hide the cut
	cut_plane.visible = false
	
	self.compile_button.icon = self.not_compiled_icon

# The goal is to unravel the tree, converting all the translation
# and consturction indices into a global index space.
# 
# We know the original shape symbol, which is required for the creation of
# the rule. The symbol determines the first indices (they are the original indices).
# The indices after that have to be added recursively.
#
# The recursion step is as follows:
#  1. Get the map from polyhedrons indices to global indices
#  2. Translate the translations and constructions indices to global indices
#    - if an index does not exist, create it (GrammarRule::add_*_vertex)
#    - this new index should also be added to the global mapper
#  3. Repeat on the child, with parents global indices as the base for the translation
#  4. At leaves, add productions
func _get_rule(item, parent_global_indices, rule_object):
	var tm = item.get_metadata(TREE_META)
	# If epsilon, do nothing
	if tm.epsilon:
		return
		
	# Get the rotation
	var rotation = []
	for i in tm.poly.vertices.size():
		rotation.push_back(i)
		
	for rot in tm.rotations:
		var new_rotation = []
	
		for new_i in rot.size():
			var old_i = rot[new_i]
			new_rotation.push_back(rotation[old_i])
			
		rotation = new_rotation
		
	# Apply rotation to parent indices
	var rotated_pgi = parent_global_indices.duplicate()
	
	# Get the global indices of the local poly
	var local_to_global = []
	for i in tm.parent_indices:
		# The vertex has to be constructed (a cut vertex)
		if tm.constructions.has(i):
			var inter_data = tm.constructions[i]
			var global_a = parent_global_indices[inter_data[0]]
			var global_b = parent_global_indices[inter_data[1]]
			var new_index = rule_object.add_interpolated_vertex(global_a, global_b, inter_data[2])
			local_to_global.push_back(new_index)
			pass
			
		# The vertex is inherited from the parent
		else:
			local_to_global.push_back(parent_global_indices[i])
			
	# Rotate the local vertices
	var rotated_local_to_global = []
	rotated_local_to_global.resize(local_to_global.size())
	Polyhedron._place(rotated_local_to_global, local_to_global, rotation)
	
	# Recursion step
	var child = item.get_children()
	
	# Leaf case
	if child == null:
		# Get the symbol
		var sym = tm.poly.symbol
		
		# If the symbol does not exist, create a new one
		if sym == null:
			sym = self.symbol_gen.from_polyhedron(tm.poly, "_terminal")
		
		# Add the production
		rule_object.add_product(sym, rotated_local_to_global)
	
	# Call for each child
	else:
		while child != null:
			_get_rule(child, rotated_local_to_global, rule_object)
			child = child.get_next()
	
func get_rule(tree):
	var root_item = tree.get_root()
	var tm = root_item.get_metadata(TREE_META)
	var new_rule = GrammarRule.new(tm.poly.symbol)
	
	var indices = []
	for i in tm.poly.symbol.nr_of_vertices:
		indices.push_back(i)
	
	# Populate the rule with construction vertices
	_get_rule(root_item, indices, new_rule)
	
	return new_rule
	
func _on_compile_button_press():
	var rule = get_rule(self.split_tree)
	
	# Add the rule to the root shape
	var tm = self.split_root.get_metadata(TREE_META)
	tm.poly.symbol.rules = [] # Currently only one rule
	tm.poly.symbol.add_rule(rule)
	
	self.compile_button.icon = self.compiled_icon

var _shapes = []
var _terminals = []
var _shape_meshes = []
var _terminal_meshes = []

func _add_terminal(terminal_shape):
	self._terminals.push_back(terminal_shape)
	
	var _meshes = terminal_shape.get_meshes()
	var mesh_instances = []
	for mesh in _meshes:
		var new_inst = MeshInstance.new()
		new_inst.mesh = mesh
		mesh_instances.push_back(new_inst)
		
	self._add_random_color(mesh_instances)
	
	for mi in mesh_instances:
		self._terminal_meshes.push_back(mi)
		$Tester.add_child(mi)
		
func _clear_terminals():
	for tm in self._terminal_meshes:
		tm.queue_free()
		
	for t in self._terminals:
		t.free()
		
	self._terminal_meshes = []
	self._terminals = []

func _refresh_shapes():
	# Free the old shapes
	for sm in self._shape_meshes:
		sm.queue_free()
		
	self._shape_meshes = []
		
	# Add the new shape to the Tester
	for shape in self._shapes:
		var _meshes = shape.get_meshes()
		var mesh_instances = []
		for mesh in _meshes:
			var new_inst = MeshInstance.new()
			new_inst.mesh = mesh
			mesh_instances.push_back(new_inst)
			
		self._add_random_color(mesh_instances)
		
		for mi in mesh_instances:
			self._shape_meshes.push_back(mi)
			$Tester.add_child(mi)

# Hide children and 
func _on_test_grammar_press():
	if _shapes.size() == 0:
		var tm = self.split_root.get_metadata(TREE_META)
		var root_poly = tm.poly
		
		var new_shape = GrammarShape.new(root_poly.symbol, root_poly.vertices)
		self._shapes.push_back(new_shape)
		
		self._refresh_shapes()
		
	else:
		for shape in self._shapes:
			shape.free()
		
		self._shapes = []
		
		self._refresh_shapes()
		self._clear_terminals()
		
	# Swap visiblilities
	$Editor.visible = not $Editor.visible
	$Tester.visible = not $Tester.visible
	
	# Toggle the ability of the generation button
	self.apply_rule.disabled = not self.apply_rule.disabled

# Fulfill a grammar
func _on_apply_rule_press():
	var new_shapes = []
	for shape in self._shapes:
		# Beware of terminal symbols
		if shape.symbol.rules.size() == 0:
			self._add_terminal(shape)
			continue
			
		# Get the rule
		var rule = shape.symbol.rules[0]
		
		var shapes = rule.fulfill(shape)
		
		new_shapes.append_array(shapes)
		
	self._shapes = new_shapes
	self._refresh_shapes()

const _matching_sym_color = Color(0.3, 1, 0.1, 0.05)

func _on_item_edited():
	var item = self.split_tree.get_edited()
	var new_text = item.get_text(TREE_SYMBOL)
	var tm = item.get_metadata(TREE_META)

	# Does this symbol exist?
	if self.symbol_gen.symbols.has(new_text):
		item.set_custom_bg_color(TREE_SYMBOL, _matching_sym_color)
		var sym = self.symbol_gen.symbols[new_text]
		tm.poly.symbol = sym
		
		# Find the correct face to anchor
		#var first_face = tm.poly.get_first_face() # TODO: this is indices, we need Face object
		#var new_anchor = self.anchor_manager.get_face_anchors(tm.poly, 0, sym)
		#first_face.set_face(new_anchor)
		var anchor_node = self.anchor_manager.add_poly(tm.poly, sym)
		$Editor.add_child(anchor_node)
		
		tm.poly.create_copy()
		
	else:
		item.clear_custom_bg_color(TREE_SYMBOL)
		tm.poly.symbol = null
		
		self.anchor_manager.remove_poly(tm.poly)

func _on_poly_reorder(poly, new_order):
	# Remove old meshes
	self._retire_poly(poly)
	
	# Add new meshes
	self.poly_to_meshes(poly)
	
	# TODO: add the rotation info to the tree
	var item = self.poly_to_treeitem[poly]
	var tm = item.get_metadata(TREE_META)
	tm.rotations.push_back(new_order)
	pass
