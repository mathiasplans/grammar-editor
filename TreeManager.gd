extends Node
class_name TreeManager

signal tree_edited

const button_visible_tex = preload("res://icons/GuiVisibilityVisible.svg")
const button_hidden_tex = preload("res://icons/GuiVisibilityHidden.svg")
const button_epsilon = preload("res://icons/Greek_lc_epsilon.png")
const button_epsilon_not = preload("res://icons/Greek_lc_epsilon_dis.png")
const shape_icon = preload("res://icons/aneZtd-cube-cut-out.png")
const scissors_icon = preload("res://icons/scissors.png")
const button_xray_tex = preload("res://icons/GuiVisibilityXray.svg")

enum {NODE_POLY, NODE_SPLIT}
enum {TREE_SYMBOL, tree_nr_of_cols, TREE_META = TREE_SYMBOL, TREE_BUTTONS = TREE_SYMBOL}
enum {BUTTON_HIDE, BUTTON_EPSILON, BUTTON_CREATE_SYMBOL, tree_nr_of_buttons}
enum {VIS_XRAY, VIS_VISIBLE, VIS_amount}

var hidden_to_tex = {VIS_VISIBLE: button_visible_tex, VIS_XRAY: button_hidden_tex}
var epsilon_to_tex = {true: button_epsilon, false: button_epsilon_not}

var trees = []
var current_tree

var tree_symbols = {}
var tree_to_rule = {}

func _ready():
	%Editor/Selector.polyhedron_selected.connect(_on_polyhedron_selected)
	%Editor/Selector.polyhedron_deselected.connect(_on_polyhedron_deselect)
	
	%Symbols.symbol_created.connect(_on_symbol_create)
	%Symbols.symbol_deleted.connect(_on_symbol_delete)
	%Symbols.symbol_renamed.connect(_on_symbol_rename)

func _hidden_button_change(treeitem, tm):
	var hide_index = treeitem.get_button_by_id(TREE_BUTTONS, BUTTON_HIDE)
	treeitem.set_button(TREE_BUTTONS, hide_index, hidden_to_tex[tm.hidden])

class TreeMeta:
	var poly = null
	var hidden = VIS_VISIBLE
	var epsilon = false
	var leaf = true
	var other_hidden = VIS_VISIBLE
	var cut_type = Mode.NONE
	
	var parent_indices = []
	var constructions = []
	
	var rotations = []
	
	var symbol = ""
	
	func serialize():
		var poly_save = self.poly.save()
		return [poly_save, hidden, epsilon, leaf, other_hidden, cut_type, parent_indices, constructions, rotations, symbol]
		
	func deserialize(ser):
		self.poly = Polyhedron.from_data(ser[0])
		self.hidden = ser[1]
		self.epsilon = ser[2]
		self.leaf = ser[3]
		self.other_hidden = ser[4]
		self.cut_type = ser[5]
		self.parent_indices = ser[6]
		self.constructions = ser[7]
		self.rotations = ser[8]
		self.symbol = ser[9]

static func serialize_tree(item, store):
	# Get meta_data
	var tm = item.get_metadata(TREE_META)
	
	# Store current
	store.append(tm.serialize())
	
	var kids = item.get_children()
	
	if kids.size() > 0:
		store.append(true)
		for child in item.get_children():
			serialize_tree(child, store)
		
	store.append(false)
	
static func deserialize_tree(tree, parent, store, _cursor=0):
	while true:
		var val = store[_cursor]
		if typeof(val) == TYPE_BOOL:
			if val:
				_cursor = deserialize_tree(tree, parent, store, _cursor + 1)
				
			else:
				break
				
		else:
			parent = tree.create_item(parent)
			var tm = TreeMeta.new()
			tm.deserialize(val)
			_treeitem_setup(parent, tm, "")
			_cursor += 1
				
	return _cursor + 1

static func _add_epsilon_button(item):
	item.add_button(TREE_BUTTONS, button_epsilon_not, BUTTON_EPSILON, false, "Convert this shape into an empty shape")

static func _treeitem_setup(item, metadata, _text):
	_add_epsilon_button(item)
	item.add_button(TREE_BUTTONS, button_visible_tex, BUTTON_HIDE, false, "Change the visibility of this shape")
	
	item.set_metadata(TREE_META, metadata)
	#item.set_text(TREE_TEXT, text)
	
	item.set_icon(0, shape_icon)
	
	item.set_editable(TREE_SYMBOL, true)
	
# Called when the node enters the scene tree for the first time.
func create_tree(rule, poly):
	# Temporary
	rule.split_tree = Tree.new()
	var new_tree = rule.split_tree
	
	rule.split_tree.columns = tree_nr_of_cols
	rule.split_root = new_tree.create_item()
	var tm = TreeMeta.new()
	tm.poly = poly
	
	for i in rule.from_shape.symbol.nr_of_vertices:
		tm.parent_indices.push_back(i)

	rule.poly_to_treeitem[poly] = rule.split_root

	_treeitem_setup(rule.split_root, tm, "A")
	
	# Connect the signals
	rule.split_tree.button_clicked.connect(_on_tree_button)
	rule.split_tree.item_selected.connect(_on_tree_selected)
	rule.split_tree.item_edited.connect(_on_item_edited)

	self.trees.push_back(new_tree)
	self.tree_symbols[new_tree] = {}
	
	for symbol in %Symbols.get_symbols():
		self.tree_symbols[new_tree][symbol] = []
		
	self.tree_to_rule[new_tree] = rule

	return new_tree
	
func delete_tree(tree):
	self.tree_symbols.erase(tree)
	self.trees.erase(tree)
	tree.queue_free()
	
func remove_tree():
	if self.current_tree != null:
		%TreeParent.remove_child(self.current_tree)
		
	self.current_tree = null
	
func set_tree(tree):
	if tree != null:
		if self.current_tree != null:
			%TreeParent.remove_child(self.current_tree)
		
		self.current_tree = tree
		%TreeParent.add_child(self.current_tree)
	
func create_child_item(cut, parent_poly, text, sym=null):
	var parent_treeitem = %RuleManager.get_treeitem(parent_poly)
	
	var poly = cut[0]
	var pos = cut[1]
	var construction = cut[2]
	
	# Set the symbol
	poly.symbol = sym
	
	# Add the new polyhedrons and the split to the tree
	var new_treeitem = self.current_tree.create_item(parent_treeitem)
	
	var tm = TreeMeta.new()
	tm.poly = poly
	tm.parent_indices = pos
	tm.constructions = construction
	
	_treeitem_setup(new_treeitem, tm, text)
	
	%RuleManager.set_treeitem(poly, new_treeitem)
	%RuleManager.set_leafness(poly)
	
	self.tree_edited.emit()
	
func _remove_leafness_item(item):
	var tm = item.get_metadata(TREE_META)
	tm.leaf = false
	
	# Change the icon
	item.set_icon(TREE_SYMBOL, scissors_icon)
	
	# Remove the epsilon button
	var index = item.get_button_by_id(TREE_BUTTONS, BUTTON_EPSILON)
	item.erase_button(TREE_BUTTONS, index)
	
	# Make the text non-editable
	item.set_editable(TREE_SYMBOL, false)

func remove_leafness(poly, rule):
	var item = %RuleManager.get_treeitem(poly, rule)
	self._remove_leafness_item(item)
	
	if %RuleManager.current_rule == rule:
		self.tree_edited.emit()
	
func add_split(poly, split):
	var item = %RuleManager.get_treeitem(poly)
	var tm = item.get_metadata(TREE_META)
	tm.cut_type = split.cut_mode
	
	self.tree_edited.emit()
	
func add_rotation(poly, rotation):
	var item = %RuleManager.get_treeitem(poly)
	var tm = item.get_metadata(TREE_META)
	tm.rotations.push_back(rotation)
	
	self.tree_edited.emit()

func _treeitem_set_visibility(item):
	var tm = item.get_metadata(TREE_META)
	if tm.leaf:
		var state = tm.hidden
		
		var t = false
		if tm.epsilon:
			%RuleManager.set_visibility(tm.poly, false)
			
		elif state == VIS_XRAY:
			t = true
			%RuleManager.set_visibility(tm.poly, true)
			
		elif state == VIS_VISIBLE:
			%RuleManager.set_visibility(tm.poly, true)
			
		if t:
			%RuleManager.set_transparency(tm.poly, 0.2)
			%RuleManager.set_collision(tm.poly, false)
			
		else:
			%RuleManager.set_transparency(tm.poly, 1.0)
			%RuleManager.set_collision(tm.poly, true)

func _treeitem_visible(item, vis):
	var tm = item.get_metadata(TREE_META)
	tm.hidden = vis
	
	# Change the icon
	self._hidden_button_change(item, tm)
	
	if not tm.epsilon:	
		_treeitem_set_visibility(item)

		var children = item.get_children()
		for child in children:
			_treeitem_visible(child, vis)
			
func _treeitem_epsilonize(item, eps):
	var tm = item.get_metadata(TREE_META)
	tm.epsilon = eps
	
	_treeitem_set_visibility(item)
	
	var epsilon_index = item.get_button_by_id(TREE_BUTTONS, BUTTON_EPSILON)
	item.set_button(TREE_BUTTONS, epsilon_index, epsilon_to_tex[tm.epsilon])
	
	self.tree_edited.emit()

func _on_tree_button(item, column, id, _mouse_button_index):
	var tm = item.get_metadata(TREE_META)
	if column == TREE_BUTTONS:
		if id == BUTTON_HIDE:
			%Editor/Selector.select_clear()
			
			if Input.is_physical_key_pressed(KEY_SHIFT):
				if tm.other_hidden == VIS_XRAY:
					tm.other_hidden = VIS_VISIBLE
				
				else:
					tm.other_hidden = VIS_XRAY
				
				var parent = item.get_parent()
				
				while parent != null:
					var children = parent.get_children()
					for child in children:
						if child != item:
							self._treeitem_visible(child, tm.other_hidden)
							
					item = parent
					parent = parent.get_parent()

			else:
				self._treeitem_visible(item, (tm.hidden + 1) % VIS_amount)
			
		elif id == BUTTON_EPSILON:
			%Editor/Selector.select_clear()
			self._treeitem_epsilonize(item, not tm.epsilon)
			%RuleManager.visaul_changed()
			
		elif id == BUTTON_CREATE_SYMBOL:
			%Editor/Selector.select_clear()
			var rule = %RuleManager.get_rule()
			self._on_item_edited(item)
			var sym_text = item.get_text(TREE_SYMBOL)
			%AddSymbol.create_symbol(tm.poly, sym_text)
			self.anchor_update(item, sym_text, rule)
			

func _on_tree_selected():
	var selected_item = self.current_tree.get_selected()
	var meta = selected_item.get_metadata(TREE_META)
	
	# Get one of the faces
	if %RuleManager.is_leaf(meta.poly):
		var face = %RuleManager.get_meshes(meta.poly)[0]
	
		# Select signal should be omited for the next selection
		%Editor/Selector.no_select_signal()
		%Editor/Selector.select_poly(face)
		
	else:
		pass
	
func _on_polyhedron_selected(poly, rule):
	var item = rule.get_treeitem(poly)
	item.select(TREE_SYMBOL)
	
func _on_polyhedron_deselect(poly, rule):
	var item = rule.get_treeitem(poly)
	item.deselect(TREE_SYMBOL)

# The goal is to unravel the tree, converting all the position
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
#  3. Repeat on the child, with parents global indices as the base for the position
#  4. At leaves, add productions
func _get_grammar_rule(item, parent_global_indices, rule_object):
	var tm = item.get_metadata(TREE_META)
	# If epsilon, do nothing
	if tm.epsilon:
		return
	
	# Get the rotation
	var vert_rotation = []
	for i in tm.poly.vertices.size():
		vert_rotation.push_back(i)

	for rot in tm.rotations:
		var new_rotation = []

		for new_i in rot.size():
			var old_i = rot[new_i]
			new_rotation.push_back(vert_rotation[old_i])

		vert_rotation = new_rotation
	
	# Construct new vertices.
	# This has to be done before the local_to_global because
	# some vertices that need to be constructed are not
	# in parent_indices.
	var cons = {}
	for i in tm.constructions:
		var inter_data = tm.constructions[i]
		
		var global_a
		var global_b
		
		if cons.has(inter_data[0]):
			global_a = cons[inter_data[0]]
				
		else:
			global_a = parent_global_indices[inter_data[0]]
			
		if cons.has(inter_data[1]):
			global_b = cons[inter_data[1]]
			
		else:
			global_b = parent_global_indices[inter_data[1]]
		
		var new_index = rule_object.add_interpolated_vertex(global_a, global_b, inter_data[2])
		cons[i] = new_index
	
	# Get the global indices of the local poly
	var local_to_global = []
	for i in tm.parent_indices:
		# The vertex has to be constructed (a cut vertex)
		if tm.constructions.has(i):
			var new_index = cons[i]
			local_to_global.push_back(new_index)
			
		# The vertex is inherited from the parent
		else:
			local_to_global.push_back(parent_global_indices[i])
			
	# Rotate the local vertices
	var rotated_local_to_global = []
	rotated_local_to_global.resize(local_to_global.size())
	Polyhedron._place(rotated_local_to_global, local_to_global, vert_rotation)
	
	# Recursion step
	var children = item.get_children()
	
	# Leaf case
	if children.size() == 0:
		# Get the symbol
		var sym = tm.poly.symbol
		
		# If the symbol does not exist, create a new one
		if sym == null:
			sym = %Symbols.from_polyhedron(tm.poly)
		
		# Add the production
		rule_object.add_product(sym, rotated_local_to_global)
	
	# Call for each child
	else:
		for child in children:
			_get_grammar_rule(child, rotated_local_to_global, rule_object)
	
func create_grammar_rule(rule=%RuleManager.current_rule):
	var index = rule.index
	var symbol = rule.from_shape.symbol
	var root_item = rule.split_root

	var new_rule = GrammarRule.new(index, symbol)
	
	var indices = []
	for i in symbol.nr_of_vertices:
		indices.push_back(i)
	
	# Populate the rule with construction vertices
	self._get_grammar_rule(root_item, indices, new_rule)
	
	return new_rule

const _matching_sym_color = Color(0.3, 1, 0.1, 0.05)

func _remove_anchor(rule, treeitem, sym):
	if sym == null:
		return
	
	var tm = treeitem.get_metadata(TREE_META)
	
	treeitem.clear_custom_bg_color(TREE_SYMBOL)
	tm.poly.symbol = null
	
	%Editor/AnchorManager.remove_poly(tm.poly)
	%RuleManager.remove_anchor(tm.poly, rule)

	if self.tree_symbols.has(self.current_tree):
		self.tree_symbols[self.current_tree][sym].erase(treeitem)

func anchor_update(item, new_text, rule=null):
	var tm = item.get_metadata(TREE_META)
	
	var old_sym = tm.poly.symbol

	# Does this symbol exist?
	if %Symbols.symbols.has(new_text):
		item.set_custom_bg_color(TREE_SYMBOL, _matching_sym_color)
		var sym = %Symbols.symbols[new_text]
		if sym != old_sym:
			# Remove the old anchor
			self._remove_anchor(%RuleManager.current_rule, item, old_sym)
			
			tm.poly.symbol = sym
			
			var anchor_node = %Editor/AnchorManager.add_poly(tm.poly, sym)
			
			# Use the current rule and tree
			if rule == null:
				rule = %RuleManager.get_rule()
				
			%RuleManager.add_anchor(tm.poly, anchor_node, rule)
		
		var epsilon_index = item.get_button_by_id(TREE_BUTTONS, BUTTON_EPSILON)
		item.set_button_disabled(TREE_BUTTONS, epsilon_index, true)
		self.disable_create_symbol(item)
		
	# Change from a symbol to not symbol
	else:
		# Remove the old anchor
		self._remove_anchor(%RuleManager.current_rule, item, old_sym)
		
		if new_text == "":
			
			var epsilon_index = item.get_button_by_id(TREE_BUTTONS, BUTTON_EPSILON)
			if epsilon_index >= 0:
				item.set_button_disabled(TREE_BUTTONS, epsilon_index, false)
			self.disable_create_symbol(item)
			
		else:
			var epsilon_index = item.get_button_by_id(TREE_BUTTONS, BUTTON_EPSILON)
			item.set_button_disabled(TREE_BUTTONS, epsilon_index, true)
			self.enable_create_symbol(item)

# TODO: more locally near anchor manager
func _on_item_edited(item=null):
	if item == null:
		item = self.current_tree.get_edited()
		
	var tm = item.get_metadata(TREE_META)

	var new_text = item.get_text(TREE_SYMBOL)
	tm.symbol = new_text
	
	self.anchor_update(item, new_text)
		
func enable_create_symbol(item):
	var index = item.get_button_by_id(TREE_BUTTONS, BUTTON_CREATE_SYMBOL)
	
	if index == -1:
		item.add_button(TREE_BUTTONS, self.shape_icon, BUTTON_CREATE_SYMBOL, false, "Create a new symbol with equal topology")

func disable_create_symbol(item):
	var index = item.get_button_by_id(TREE_BUTTONS, BUTTON_CREATE_SYMBOL)
	
	if index != -1:
		item.erase_button(TREE_BUTTONS, index)

func _on_symbol_create(symbol):
	for tree in self.trees:
		self.tree_symbols[tree][symbol] = []

func _on_symbol_delete(symbol):
	for tree in self.trees:
		var rule = self.tree_to_rule[tree]
		var items = self.tree_symbols[tree][symbol]
		
		for item in items:
			self._remove_anchor(rule, item, symbol)
			item.set_text(TREE_SYMBOL, "")
		
		self.tree_symbols[tree].erase(symbol)

func _on_symbol_rename(symbol, new_name):
	for tree in self.trees:
		var items = self.tree_symbols[tree][symbol]
		
		for item in items:
			item.set_text(TREE_SYMBOL, new_name)
			
func is_visible(item):
	var tm = item.get_metadata(TREE_META)
	return !tm.epsilon and tm.hidden == VIS_VISIBLE
	
static func get_leafpolys(dict, item):
	var tm = item.get_metadata(TREE_META)
	if tm.leaf:
		dict[tm.poly] = true
		
	for child in item.get_children():
		get_leafpolys(dict, child)

static func get_polytoitem(dict, item):
	var tm = item.get_metadata(TREE_META)
	dict[tm.poly] = item
	
	for child in item.get_children():
		get_polytoitem(dict, child)
		
func refresh(item=self.current_tree.get_root()):
	var tm = item.get_metadata(TREE_META)
	if not tm.leaf:
		self._remove_leafness_item(item)
		
	self._hidden_button_change(item, tm)
	self._treeitem_set_visibility(item)
	
	var tree = item.get_tree()
	var rule = self.tree_to_rule[tree]
	self.anchor_update(item, tm.symbol, rule)
	
	for child in item.get_children():
		self.refresh(child)
		
func refresh_tree(tree=self.current_tree):
	var root_item = tree.get_root()
	self.refresh(root_item)
	
func refresh_all():
	for tree in self.trees:
		self.refresh_tree(tree)
