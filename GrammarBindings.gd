class_name GB

static func get_meshes(shape: GrammarShape):
	return Geom.brep_to_meshes(shape.vertices, shape.symbol.faces)
	
static func get_polyhedron(shape: GrammarShape):
	return GB.create_polyhedron(shape.symbol, shape.vertices)	

static func get_vertices(shape: GrammarShape, transform=Transform3D()):
	var verts = []
	for vert in shape.vertices:
		verts.append(transform * vert)
		
	return verts

static func create_polyhedron(symbol: GrammarSymbol, vertices):
	var newpoly = Polyhedron.new()
	
	newpoly.add_vertices(vertices)
	newpoly.add_faces(symbol.faces)
	newpoly.complete()
	
	return newpoly
	
