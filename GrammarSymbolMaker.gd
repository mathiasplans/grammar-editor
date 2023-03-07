extends Node
class_name GrammarSymbolMaker

var symbols = {}

func _poly_to_symbol(poly, _terminal=true):
	if not poly.is_ordered():
		assert(false, "The polygon has to be ordered by anchor first before it can be turned into a symbol")
		return null
	
	var newsym = GrammarSymbol.new(poly.vertices.size(), poly.faces, _terminal)
	return newsym
	
func from_polyhedron(poly, text, _terminal=true):
	
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
				
	# Add the symbold to a list
	self.symbols[text] = unique_symbol
	
	return unique_symbol
