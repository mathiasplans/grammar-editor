extends Node
class_name GrammarSymbolMaker
signal symbol_created(symbol)
signal symbol_deleted(symbol)
signal symbol_renamed(old_text, new_text)

var symbols = {}
var symbols_id = {}
var default_shape = {}
var symbol_objects = {}

var index_counter = 0
var non_terminal_index_counter = 0

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
		new_name = "Terminal %d" % self.index_counter
		
	else:
		new_name = "Symbol %d" % self.non_terminal_index_counter
		self.non_terminal_index_counter += 1
		
	unique_symbol.text = new_name
	unique_symbol.id = self.index_counter
	
	self.index_counter += 1
	
	# Add the symbold to a list
	self.symbols[unique_symbol.text] = unique_symbol
	self.symbols_id[unique_symbol.id] = unique_symbol
	
	# Create a default shape object
	self.default_shape[unique_symbol] = GrammarShape.new(unique_symbol, poly.vertices)
	
	# Symbol object (to be rendered)
	self.symbol_objects[unique_symbol] = Symbol.new(unique_symbol)
	
	if not _terminal:
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
