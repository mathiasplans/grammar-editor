extends Node
class_name GrammarShape

var symbol = null
var vertices = []

# Persistant:
# * symbol
# * vertices

func save():
	return [symbol.text, self.vertices]
	
static func from_data(data, symbols):
	return GrammarShape.new(symbols.get_symbol[data[0]], data[1])
	
func serialize():
	var data = PackedByteArray()
	
	var s = 4 + vertices.size() * 3 * 4
	s = snappedi(s + 1.5, 4)
	data.resize(s)
	
	var i = 0
	data.encode_u32(i, data.size())
	i += 4
	
	for vertex in self.vertices:
		for j in 3:
			data.encode_float(i, vertex[j])
			i += 4
			
	return data

func _init(_symbol, _vertices):
	self.symbol = _symbol
	self.vertices = _vertices

func get_meshes():
	return Geom.brep_to_meshes(self.vertices, self.symbol.faces)
	
func get_polyhedron():
	return self.symbol.create_polyhedron(self.vertices)

func get_vertices(transform=Transform3D()):
	var verts = []
	for vert in self.vertices:
		verts.append(transform * vert)
		
	return verts
