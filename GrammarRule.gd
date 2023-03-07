extends Node
class_name GrammarRule

class VirtualVertex:
	var from
	var to
	
	enum {FIRST, INTERPOLATE}
	
	func _init(_from,_to):
		self.from = _from
		self.to = _to
		
	func create_vertex(_vertex_array):
		pass
		
class FirstVertex:
	extends VirtualVertex
	
	func _init(_from):
		super(_from, -1)
		pass
		
	func create_vertex(vertex_array):
		return vertex_array[self.from]
		
class InterpolateVertex:
	extends VirtualVertex
	var coef
	
	func _init(_from, _to, _coef):
		super(_from, _to)
		self.coef = _coef
		
	func create_vertex(vertex_array):
		var other_coef = 1 - self.coef
		return vertex_array[self.from] * other_coef + vertex_array[self.to] * self.coef 

var symbol = null
var vertex_counter = -1
var virtual_vertices = []
var product_symbols = []
var product_vertices = []

func _init(_symbol):
	self.symbol = _symbol
	self.vertex_counter = self.symbol.nr_of_vertices
	
	self.symbol.add_rule(self)
	
func _add(vv):
	self.virtual_vertices.push_back(vv)
	var vv_index = self.vertex_counter
	self.vertex_counter += 1
	return vv_index

func add_copy_vertex(index):
	var vv = FirstVertex.new(index)
	return self._add(vv)
	
func add_interpolated_vertex(index1, index2, inter_coef):
	var vv = InterpolateVertex.new(index1, index2, inter_coef)
	return self._add(vv)
	
func add_product(_symbol, indices):
	self.product_symbols.push_back(_symbol)
	self.product_vertices.push_back(indices)

static func _select_vertices(va, indices):
	var selection = []
	for i in indices:
		selection.push_back(va[i])
		
	return selection

func fulfill(shape):
	var va = []
	va.append_array(shape.vertices)

	# Create virtual vertices
	for vv in self.virtual_vertices:
		var new_vertex = vv.create_vertex(va)
		va.push_back(new_vertex)

	# Create children
	var children = []
	for i in self.product_symbols.size():
		var sym = self.product_symbols[i]
		var indices = self.product_vertices[i]
		
		var selection = GrammarRule._select_vertices(va, indices)
		
		var new_shape = GrammarShape.new(sym, selection)
		children.push_back(new_shape)

	return children
