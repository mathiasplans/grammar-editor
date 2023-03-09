extends Node
class_name GrammarShape

var symbol = null
var vertices = []

func _init(_symbol, _vertices):
	self.symbol = _symbol
	self.vertices = _vertices

func get_meshes():
	return Geom.brep_to_meshes(self.vertices, self.symbol.faces)
	
func get_polyhedron():
	return self.symbol.get_polyhedron(self.vertices)
