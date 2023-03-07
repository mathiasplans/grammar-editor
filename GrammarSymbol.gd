extends Node
class_name GrammarSymbol

var uuid = -1

var nr_of_vertices = 0
var faces = []
var terminal = true

var rules = []
# var rule_weights = []

func _init(_nr_of_verts, _faces, _terminal=true):	
	self.nr_of_vertices = _nr_of_verts
	self.faces = _faces.duplicate(true)
	self.terminal = _terminal

func has_same_topology_as(other):
	return self.nr_of_vertices == other.nr_of_vertices and self.faces == other.faces
	
func can_be_assigned_to(poly):
	return self.nr_of_vertices == poly.vertices.size() and self.faces == poly.faces

func create_polyhedron(vertices):
	var newpoly = Polyhedron.new(self)
	
	newpoly.add_vertices(vertices)
	newpoly.add_faces(self.faces)
	newpoly.complete()
	
	return newpoly
	
func add_rule(rule):
	self.rules.push_back(rule)
