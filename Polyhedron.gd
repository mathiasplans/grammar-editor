extends Node
class_name Polyhedron

var vertices = []
var directed = {}
var faces = []
var directed_to_face = {}
var face_to_face = {}
var face_next = {}
var face_objs = []

var cut_points = []
var cut_edges = {}
var cut_face_to_face = {}

var symbol = null
var original = false

func _init(_symbol=null):
	self.symbol = _symbol

func add_vertex(vert : Vector3):
	self.vertices.push_back(vert)
	var i = self.vertices.size() - 1
	self.directed[i] = []
	return i
	
func add_vertices(verts):
	for vert in verts:
		self.add_vertex(vert)
	
func _add_edge(i1, i2):	
	self.directed[i1].push_back(i2)
	
func _min_cycle(a):
	# Get the smallest element
	var minel = a.min()
	
	# Get the index of the smallest element
	var minel_i = 0
	for i in a.size():
		if a[i] == minel:
			minel_i = i
			break
			
	if minel_i == 0:
		return a
		
	# Get the slices before and after the smallest element
	var before = a.slice(0, minel_i)	
	var after = a.slice(minel_i, a.size())
	
	# Cycle the array
	after.append_array(before)
	
	return after
	
func get_meshes():
	return Geom.brep_to_meshes(self.vertices, self.faces)
	
func _get_face_mesh(face_i):
	return Geom.brep_to_meshes(self.vertices, [self.faces[face_i]])[0]
	
func _create_face_object(face_i):
	var mesh = self._get_face_mesh(face_i)
	var hull_indices = self.faces[face_i]
	
	# Create the instance for the mesh
	return Face.new(mesh, self, hull_indices, face_i)
	
func get_face_objects():
	return self.face_objs
	
func _face_setup(face_i):
	self.face_to_face[face_i] = []
	self.face_next[face_i] = {}
	
func _forget_face_metadata():
	self.face_to_face = {}
	self.directed_to_face = {}
	self.face_next = {}
	self.face_objs = []
	
	for face_i in self.faces.size():
		self._face_setup(face_i)

# Calculate the face metadata
func _face_metadata(face_i):
	var face = self.faces[face_i]
	
	if face_i >= self.face_objs.size():
		self.face_objs.resize(face_i + 1)
		
	self.face_objs[face_i] = self._create_face_object(face_i)
	
	self.cut_face_to_face[face_i] = []
	var next = self.face_next[face_i]
	for i_i in face.size():
		var next_i_i = (i_i + 1) % face.size()
		
		var i = face[i_i]
		var next_i = face[next_i_i]
		
		self.directed_to_face[[i, next_i]] = face_i
		next[i] = next_i
		
		# Face to face
		if self.directed_to_face.has([next_i, i]):
			var other_face_i = self.directed_to_face[[next_i, i]]
			
			self.face_to_face[face_i].push_back(other_face_i)
			self.face_to_face[other_face_i].push_back(face_i)
			
			# Lable these edges as cut edges
			if self.cut_edges.has(next_i) and self.cut_edges[next_i].has(i):
				self.cut_face_to_face[face_i].push_back(other_face_i)
				self.cut_face_to_face[other_face_i].push_back(face_i)
	
func add_face(indices):
	# Reorder indices so that the smallest index is first
	indices = _min_cycle(indices)
	
	# TODO: check that the verts are on the same plane
	# In circle, add edges
	for i_i in indices.size():
		var next_i_i = (i_i + 1) % indices.size()
		
		var i = indices[i_i]
		var next_i = indices[next_i_i]
		
		self._add_edge(i, next_i)
	
	# Add it to the face
	self.faces.push_back(indices)
	var face_i = self.faces.size() - 1
	
	# Connect faces to faces
	self._face_setup(face_i)
	self._face_metadata(face_i)
	
	return face_i
	
func add_faces(indices_array):
	for indices in indices_array:
		self.add_face(indices)
		
class ArraySorter:
	static func first_sort(a, b):
		return a[0] < b[0]
	
	static func radix_sort(a, b, i=0):
		if a.size() == 0 or b.size() == 0:
			return a.size() < b.size()
		
		elif a[i] == b[i]:
			return radix_sort(a, b, i + 1)
			
		elif a[i] < b[i]:
			return true
			
		return false
	
# With keeping the order of vertices,
# change the order of faces and all the accompanying
# structures in a strict order
func complete():
	# Forget the metadata
	self._forget_face_metadata()
	
	# Order the faces in a strict way
	self.faces.sort_custom(Callable(ArraySorter,"radix_sort"))
	
	# And now recompile the face metadata
	for face_i in self.faces.size():
		self._face_metadata(face_i)
	
func get_hulls():
	var hulls = []
	for face in faces:
		hulls.push_back([])
		for vi in face:
			hulls.back().push_back(self.vertices[vi])
			
	return hulls
	
# Find cut points
func _cut_points(plane_point, plane_normal):
	var d = plane_point.dot(plane_normal)
	var verts_to_cuts = {}
	
	for face in self.faces:
		for i in face.size():
			# TODO: use face_next instead
			var next_i = (i + 1) % face.size()
			var origin = self.vertices[face[i]]
			var dest = self.vertices[face[next_i]]
			var vec = dest - origin
			
			var normvec = plane_normal.dot(vec)
			
			if normvec != 0:
				# Interpolation coefficient from face[i] to face[next_i]
				# contact = t * vertices[face[i]] + (1 - t) * vertices[face[next_i]]
				var normorigin = plane_normal.dot(origin)
				var t = (d - normorigin) / normvec
				
				# The line segment intersects with the plane
				if t >= 0 and t <= 1:
					var ray = t * vec;
					var contact = origin + ray
					
					# Prevent symmetrical pairs
					const e = 0.01
					var value = [t, contact]
					if t >= (1 - e):
						verts_to_cuts[face[next_i]] = value
						
					elif t <= e:
						verts_to_cuts[face[i]] = value
						
					else:
						verts_to_cuts[[face[i], face[next_i]]] = value

	return verts_to_cuts

# Create a copy with new faces
func _introduce_cut(plane_point, plane_normal):
	var points = self._cut_points(plane_point, plane_normal)
	
	# If no cuts were done, return self
	if points.size() == 0:
		return [self, {}]
	
	# Creat a new polyhedron with the same vertices
	var dup = Polyhedron.new()
	dup.add_vertices(self.vertices)
	
	# Add the cutting points
	var construction = {}
	var already = {}
	for key in points.keys():
		var val = points[key]
		
		if key is Array:
			var invkey = key.duplicate()
			invkey.reverse()
			
			var i
			
			if already.has(invkey):
				i = already[invkey]
				
			else:
				i = dup.add_vertex(val[1])
				dup.cut_edges[i] = []
				dup.cut_points.push_back(i)
				already[key] = i
				
				construction[i] = [key[0], key[1], val[0]]
					
			val.push_back(i)
		
		# No new vertices are needed
		else:
			val.push_back(key)
			dup.cut_edges[key] = []
			dup.cut_points.push_back(key)
		
	# Add faces
	for fi in self.faces.size():
		var face = self.faces[fi]
		
		# Count the number of cut points on the face
		var nr_of_cutpoints = 0
		for i in face.size():
			var next_i = (i + 1) % face.size()
			if points.has(face[i]) or points.has([face[i], face[next_i]]):
				nr_of_cutpoints += 1

		# 0 cut points means the face stays
		# 1 cut point means that the plane does not cut the face
		# 2 cut points means that the plane cuts the face
		if nr_of_cutpoints < 2:
			dup.add_face(face)
			continue
		
		var cuts = 0
		var trace = [[], []]
		var trace_i = 0
		
		var other = null
		
		for i in face.size():
			# TODO: use face_next instead
			var next_i = (i + 1) % face.size()
			
			# Get vertex indices
			var vi = face[i]
			var next_vi = face[next_i]
			
			# Add it to the new
			trace[trace_i].push_back(vi)
			
			var vcut = points.has(vi)
			var edgecut = points.has([vi, next_vi])
			var nextvcut = points.has(next_vi)
			
			# Turn a vertex into a cut point
			if vcut and not (edgecut or nextvcut):
				var cut_plane = points[vi]
				cuts += 1
				
				trace_i ^= 1
				
				# Add it to the other side as well
				trace[trace_i].push_back(vi)
				
				# Remember the edges that cut the original polyhedron
				if cuts == 2:
					dup.cut_edges[other].push_back(vi)
					dup.cut_edges[vi].push_back(other)
					
				else:
					other = vi
			
			# Add a cut to an edge
			if edgecut:
				var cut_plane = points[[vi, next_vi]]
				cuts += 1
				
				trace_i ^= 1
				
				trace[0].push_back(cut_plane[2])
				trace[1].push_back(cut_plane[2])
				
				# Remember the edges that cut the original polyhedron
				if cuts == 2:
					dup.cut_edges[other].push_back(cut_plane[2])
					dup.cut_edges[cut_plane[2]].push_back(other)
					
				else:
					other = cut_plane[2]
					
		# Add new faces
		dup.add_face(trace[0])
		dup.add_face(trace[1])
			
	return [dup, construction]
	
func get_rim():
	# Find the starting vertex
	var start_v
	var other_v
	var found = false
	for v in self.vertices.size():
		for other in self.directed[v]:
			if not self.directed_to_face.has([other, v]):
				start_v = v
				other_v = other
				found = true
				break
				
		if found:
			break
			
	if not found:
		return []
			
	# Traverse until a cycle is formed
	var vertex_path = [start_v, other_v]
	
	var done = false
	# TODO: maximum number of iterations
	while not done:
		var current_v = vertex_path.back()
		
		# Iterate through the directed paths
		for other in self.directed[current_v]:
			# Cycle is formed
			if other == start_v:
				done = true
				break
			
			# If there is no face
			if not self.directed_to_face.has([other, current_v]):
				vertex_path.push_back(other)
				break
				
	vertex_path.reverse()
	return vertex_path
	
func add_missing_faces():
	# Add the missing face
	var missing_face = self.get_rim()
	if missing_face.size() > 0:
		self.add_face(missing_face)
	
func subpoly(face_array):
	# Get vertices
	var unique_indices = {}
	for face_i in face_array:
		var face = self.faces[face_i]
		for v in face:
			unique_indices[v] = 0
			
	# Get the sub-set of vertices which preserve the former order
	var position = []
	var inverse_translation = {}
	for i in self.vertices.size():
		if unique_indices.has(i):
			inverse_translation[i] = position.size()
			position.push_back(i)

	# Create a new polyhedron
	var newpoly = Polyhedron.new()
	
	for i in position:
		newpoly.add_vertex(self.vertices[i])
		
	# Transfer the faces to the new polyhedron
	for face_i in face_array:
		var face = self.faces[face_i]
		var translated_face = []
		for v in face:
			translated_face.push_back(inverse_translation[v])
			
		newpoly.add_face(translated_face)
		
	return [newpoly, position, inverse_translation]
	
static func _place(insert_array, from, map):
	for i in insert_array.size():
		insert_array[i] = from[map[i]]
		
static func _invert_anchor_order(ao):
	var new_order = []
	new_order.resize(ao.size())
	
	for i in ao.size():
		new_order[ao[i]] = i
		
	return new_order

func _finalize_cut(cut_poly, face_partition, construction):
	# In the var faces we now have faces split between two polyhedrons
	# Now transform current polyhedron into two child polyhedri
	var poly_and_translation = cut_poly.subpoly(face_partition)
	var poly = poly_and_translation[0]
	var position = poly_and_translation[1]
	
	# Fill in the gaps
	poly.add_missing_faces()
	poly.complete()
	
	var anchor_order = poly.order_by_anchor(0, 1)
	
	# Translate the position by the anchor order
	var new_translation = []
	new_translation.resize(position.size())
	Polyhedron._place(new_translation, position, anchor_order)
	
	return [poly, new_translation, construction]

# From the poly with cut points and correct faces, split it into two
#
# Example output:
# cut = [
#  [Node:1972],
#  [0, 1, 2, 3, 8, 9, 10, 11],
#  [[8, 3, 4, 0.114313], [9, 5, 0, 0.885687], [10, 6, 1, 0.885687], [11, 7, 2, 0.885687]]]
# ]
#
# 1. Polyhedron object
# 2. Translation. Number j at index i is the i-th vertex' (in the new poly)
#    origin index (in the old poly). In other words, the index of the array
#    is in new polyhedrons index space, and the contents of the array are
#    in the old polyhedrons index space. Some of these indices might not exist
#    in the old polyhedron, see (3).
# 3. Some indices might not exist. This is the array of instustions on how to
#    create them. All the indices are in old polyhedrons index space.
func cut(plane_point, plane_normal):
	var cut_poly_construct = self._introduce_cut(plane_point, plane_normal)
			
	var cut_poly = cut_poly_construct[0]
	var construction = cut_poly_construct[1]
	
	# If no cut was made, return self
	if cut_poly.cut_edges.size() == 0:
		var mock_translation = []
		for i in self.vertices.size():
			mock_translation.push_back(i)
		
		return [[self, mock_translation, construction]]

	# One polygon should include only faces that are
	# connected via non-cut edges
	var face_partition = [[], []]

	var traversed = [0]
	var works = [[0, 0]]
	
	while works.size() > 0:
		# Get a new face
		var face_class = works.pop_back()
		var face_i = face_class[0]
		var cl = face_class[1]
		
		# Add to the class
		face_partition[cl].push_back(face_i)
		
		# Add to the working stack
		for neigh_i in cut_poly.face_to_face[face_i]:
			var change_cl = 0
			
			# If it has already been traversed, skip
			if traversed.has(neigh_i):
				continue
				
			# If the next face is over a cut
			elif cut_poly.cut_face_to_face[face_i].has(neigh_i):
				# Change the class
				change_cl = 1
			
			works.push_back([neigh_i, cl ^ change_cl])
			traversed.push_back(neigh_i)
			
	# In the var faces we now have faces split between two polyhedrons
	# Now transform current polyhedron into two child polyhedri
	var cut1 = _finalize_cut(cut_poly, face_partition[0], construction)
	var cut2 = _finalize_cut(cut_poly, face_partition[1], construction)
	
	return [cut1, cut2]
	
class _set:
	var _d = {}
	
	func add(x):
		self._d[x] = 0
		
	func remove(x):
		self._d.erase(x)
		
	func has(x):
		return self._d.has(x)
		
	func size():
		return self._d.size()

func _get_anchor_order(origin, a):
	var order = []
	
	var vertices_done = _set.new()
	var faces_done = _set.new()

	# Get the first face to process
	var face_i = self.directed_to_face[[origin, a]]	
	
	var wm = [[face_i, origin]]

	var to_be_done = self.vertices.size()
	while order.size() != to_be_done:
		# Get new item from working memory
		var item = wm.pop_back()
		
		var fi = item[0]
		var start = item[1]
		var last_vert = start
		var last_last_vert = last_vert # Danger
		var vert = self.face_next[fi][last_vert]
		
		# Add the first vertex
		if not vertices_done.has(last_vert):
			order.push_back(last_vert)
			vertices_done.add(last_vert)
		
		# Add vertices from the face
		while vert != start:
			if not vertices_done.has(vert):
				order.push_back(vert)
				vertices_done.add(vert)
				
			last_last_vert = last_vert
			last_vert = vert
			vert = self.face_next[fi][last_vert]
			
		# This face has been processed
		faces_done.add(fi)
			
		# Decide on the next job to do
		# First we check if the next face alongside the start and this face
		# has not been done
		var candidate_fi = self.directed_to_face[[start, last_vert]]
		if not faces_done.has(candidate_fi):
			wm.push_back([candidate_fi, start])
			
		# If all faces that contain the start have been done, move to a
		# new vertex
		else:
			# Go to the next vertex along the candidate
			var nv_start = last_vert
			
			# Get the next vertex along this face
			var nv_end = last_last_vert
			
			# Get the new face
			candidate_fi = self.directed_to_face[[nv_start, nv_end]]
			
			wm.push_back([candidate_fi, nv_start])
		
	return order
	
func is_ordered():
	var anchor_order = self._get_anchor_order(0, 1)
	
	for i in anchor_order.size():
		if i != anchor_order[i]:
			return false
			
	return true
		
static func _invert_map(map):
	var inverted = []
	inverted.resize(map.size())
	for i in map.size():
		var e = map[i]
		inverted[e] = i
		
	return inverted

func _change_order(vertex_order, invert=false):
	var vert_map = vertex_order
	var inverse_vert_map = Polyhedron._invert_map(vert_map)

	# Reverse ordering
	if invert:
		var temp = vert_map
		vert_map = inverse_vert_map
		inverse_vert_map = temp

	# Change the ordering of vertices
	var new_vertices = []
	new_vertices.resize(self.vertices.size())
	Polyhedron._place(new_vertices, self.vertices, vert_map)
	
	# Use new ordering in the data structures
	var new_directed = {}
	for key in self.directed.keys():
		var mapped_key = inverse_vert_map[key]
		new_directed[mapped_key] = []
		
		var next_verts = self.directed[key]
		for vert in next_verts:
			var mapped_vert = inverse_vert_map[vert]
			new_directed[mapped_key].push_back(mapped_vert)
			
	# Change the face order
	var new_faces = self.faces.duplicate(true)
	
	# Change the vertex indices inside the faces
	for i in new_faces.size():
		var face = new_faces[i]
		var new_face = []
		
		for vi in face:
			new_face.push_back(inverse_vert_map[vi])
			
		# Make sure that the first index is the smallest index
		new_faces[i] = _min_cycle(new_face)

	self.vertices = new_vertices
	self.directed = new_directed
	self.faces = new_faces
	
	# Change face ordering and generate face metadata
	self.complete()
	
func order_by_anchor(a, b):
	var anchor_order = self._get_anchor_order(a, b)
	self._change_order(anchor_order)
	return anchor_order
	
func create_copy(a=0, b=1):
	var copy = Polyhedron.new(self.symbol)
	
	copy.vertices = self.vertices.duplicate(true)
	copy.directed = self.directed.duplicate(true)
	copy.faces = self.faces.duplicate(true)
	
	copy.complete()
	
	if a != 0 or b != 1:
		copy.order_by_anchor(a, b)
	
	return copy

func get_first_face():
	return self.faces[0]

func get_first_face_obj():
	return self.face_objs[0]
	
func face_normal(face_i):
	var face = self.faces[face_i]
	return (self.vertices[face[0]] - self.vertices[face[1]]) \
	.cross(self.vertices[face[2]] - self.vertices[face[1]]).normalized()

func get_closest_edge(ray_start, ray_end, transform, only_visible=false):
	var closest_dist = 10000000000
	var closest_start
	var closest_end
	var closest_p
	for start in self.directed:
		for end in self.directed[start]:
			var edge_start = transform * self.vertices[start]
			var edge_end = transform * self.vertices[end]
			
			var face_i = self.directed_to_face[[start, end]]
			var normal = transform * self.face_normal(face_i)
			
			var face = self.faces[face_i]
			var to_cam = ray_start - transform * self.vertices[face[0]]
			
			if not only_visible or normal.dot(to_cam) > 0:
				var points = Geometry3D.get_closest_points_between_segments(edge_start, edge_end, ray_start, ray_end)
				var edge_point = points[0]
				var ray_point = points[1]
				
				var d = (edge_point - ray_point).length()
				
				# TODO: make distance comparison take distance from camera into account
				
				if d < closest_dist:
					closest_dist = d
					closest_start = start
					closest_end = end
					closest_p = transform.inverse() * edge_point

	return [closest_dist, closest_p, closest_start, closest_end]

func get_closest_vertex(ray_start, ray_end, transform, only_visible=false):
	var closest_dist = 10000000000
	var closest_vi
	
	for i in self.vertices.size():
		var vertex = transform * self.vertices[i]
		# Check visibility
		if only_visible:
			var to_cam = ray_start - vertex
			var is_visible = false
			for o in self.directed[i]:
				var face_i = self.directed_to_face[[i, o]]
				var normal = transform * self.face_normal(face_i)
				
				if normal.dot(to_cam) > 0:
					is_visible = true
					break
			
			# If not visible, go to the next vertex
			if not is_visible:
				continue
		
		var close = Geometry3D.get_closest_point_to_segment(vertex, ray_start, ray_end)
		
		var seg_to_vert = vertex - close
		var dist = seg_to_vert.length()
			
		if dist < closest_dist:
			closest_dist = dist
			closest_vi = i

	return [closest_dist, self.vertices[closest_vi], closest_vi]
