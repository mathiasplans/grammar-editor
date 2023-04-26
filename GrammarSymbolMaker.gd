extends Node
class_name GrammarSymbolMaker
signal symbol_created(symbol)
signal symbol_deleted(symbol)
signal symbol_renamed(old_text, new_text)

var symbols = {}
var symbols_id = {}
var default_shape = {}
var symbol_objects = {}
var buttons = {}
var reference_anchors = {}

var index_counter = 0
var non_terminal_index_counter = 0

@onready var referenceAnchorMat

const anchor_tex = preload("res://icons/anchor.png")

func _ready():
	self.referenceAnchorMat = StandardMaterial3D.new()
	self.referenceAnchorMat.albedo_color = Color(0, 0, 0, 0.15)
	self.referenceAnchorMat.albedo_texture = self.anchor_tex
	self.referenceAnchorMat.flags_transparent = StandardMaterial3D.Transparency.TRANSPARENCY_ALPHA
	self.referenceAnchorMat.cull_mode = StandardMaterial3D.CULL_BACK
	self.referenceAnchorMat.no_depth_test = true
	self.referenceAnchorMat.render_priority = 100

# Persistant:
# * symbols
# * symbols_id
# * default_shape
# * index_counter
# * non_terminal_index_counter

func _poly_to_symbol(poly, _terminal=true):
	assert(poly.is_ordered(), "The polygon has to be ordered by anchor first before it can be turned into a symbol")
	
	var newsym = GrammarSymbol.new(poly.vertices.size(), poly.faces, _terminal)
	return newsym
	
func from_polyhedron(poly, _terminal=true):
	# Get a unique symbol
	var unique_symbol = _poly_to_symbol(poly, _terminal)
	
	# If there is a topologically equivalent symbol and
	# not terminal, reuse instead. Only terminal symbols can be reused
	if _terminal:
		var _the_script = load("res://GrammarSymbol.gd")
	
		for sym_str in self.symbols.keys():
			var sym = self.symbols[sym_str]
			if sym.has_same_topology_as(unique_symbol) and sym.terminal:
				unique_symbol.free()
				return sym
	
	# Name the symbol
	var new_name 
	if _terminal:
		new_name = "T%d" % self.index_counter
		
	else:
		new_name = "S%d" % self.non_terminal_index_counter
		self.non_terminal_index_counter += 1
		
	unique_symbol.text = new_name
	unique_symbol.id = self.index_counter
	
	self.index_counter += 1
	
	# Add the symbold to a list
	self.symbols[unique_symbol.text] = unique_symbol
	self.symbols_id[unique_symbol.id] = unique_symbol
	
	# Create a default shape object
	self.default_shape[unique_symbol] = GrammarShape.new(unique_symbol, poly.vertices)
	
	if not _terminal:
		var ref_anchor = Anchor.new(0, 1, poly, 0, self.referenceAnchorMat, 0.76)
		self.reference_anchors[unique_symbol] = ref_anchor
	
		# Symbol object (to be rendered)
		var symbol_obj = Symbol.new(unique_symbol)
		symbol_obj.add_reference_anchor(self.get_reference_anchor(unique_symbol))
		self.symbol_objects[unique_symbol] = symbol_obj
	
		self.symbol_created.emit(unique_symbol)

	
	return unique_symbol

func set_default_shape(shape):
	self.default_shape[shape.symbol] = shape
	
func get_default_shape(symbol):
	return self.default_shape[symbol]
	
func rename(symbol, new_text):
	var old_text = symbol.text
	
	if self.symbols.has(new_text):
		return false
		
	self.symbols[new_text] = self.symbols[old_text]
	self.symbols.erase(old_text)

	symbol.text = new_text

	self.symbol_renamed.emit(symbol, new_text)

func delete_symbol(symbol):
	self.symbol_deleted.emit(symbol)
	
	self.symbols.erase(symbol.text)
	self.symbols_id.erase(symbol.id)
	var shape = self.default_shape[symbol]
	shape.free()
	self.default_shape.erase(symbol)
	self.buttons.erase(symbol)
	symbol.free()
	
func get_symbol(text):
	if self.symbols.has(text):
		return self.symbols[text]
	
	return null
	
func get_symbols():
	var symbol_list = []
	for key in self.symbols.keys():
		symbol_list.push_back(self.symbols[key])
		
	return symbol_list
	
func get_symbol_object(symbol):
	return self.symbol_objects[symbol]
	
func add_button(symbol, button):
	self.buttons[symbol] = button
	var meshes = self.symbol_objects[symbol].mesh_instances
	self.display_symbol_meshes(symbol, meshes)
	
func display_meshes(symbol, rule_index, meshes):
	self.buttons[symbol].display_meshes(rule_index, meshes)
	
func display_symbol_meshes(symbol, meshes):
	self.buttons[symbol].display_symbol_meshes(meshes)
	
func get_reference_anchor(symbol):
	# The anchor object does not want to be duplicated, so create a new mesh instance instead
	var refanch = self.reference_anchors[symbol]
	
	var new_mesh_instance = MeshInstance3D.new()
	new_mesh_instance.mesh = refanch.mesh
	new_mesh_instance.material_override = refanch.material_override
	
	return new_mesh_instance
