extends Node
class_name GrammarShape

var symbol = null
var vertices = []

# Persistant:
# * symbol
# * vertices

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
