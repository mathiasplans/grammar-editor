extends Polyhedron
class_name Cube

func _init(scale, _symbol=null):
	super(_symbol)
	var c = [
		scale * Vector3(-1, 1, -1), 
		scale * Vector3(1, 1, -1), 
		scale * Vector3(1, 1, 1), 
		scale * Vector3(-1, 1, 1), 
		scale * Vector3(-1, -1, -1),
		scale * Vector3(1, -1, -1),
		scale * Vector3(1, -1, 1),
		scale * Vector3(-1, -1, 1)
	]
	
	for v in c:
		self.add_vertex(v)
		
	self.add_face([0, 1, 2, 3])
	self.add_face([1, 5, 6, 2])
	self.add_face([4, 7, 6, 5])
	self.add_face([0, 3, 7, 4])
	self.add_face([2, 6, 7, 3])
	self.add_face([0, 4, 5, 1])
	self.complete()
