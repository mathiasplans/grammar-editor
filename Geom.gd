extends Node
class_name Geom
		
static func area_center(mesh):
	var centers = []
	var areas = []
	var total_area = 0
	
	var faces = mesh.get_faces()
	for vi in range(0, faces.size(), 3):
		var v1 = faces[vi]
		var v2 = faces[vi + 1]
		var v3 = faces[vi + 2]
		
		centers.push_back((v1 + v2 + v3) / 3)
		
		var area = (v1 - v2).cross(v3 - v2).length() / 2
		areas.push_back(area)
		total_area += area
		
	var centroid = Vector3(0, 0, 0)
	
	for i in centers.size():
		centroid += centers[i] * areas[i] / total_area
		
	return centroid
	
static func convex_hull_center(points):
	var sum = Vector3(0, 0, 0)
	
	for p in points:
		sum += p
		
	return sum / points.size()
	
static func _insert_brep(points, face, uv, st: SurfaceTool, color: Color):
	if color == null:
		color = Color(1, 1, 1, 1)
	
	var normal = calculate_normal_from_points(
			points[face[0]],
			points[face[1]],
			points[face[2]]
	)
	
	# Triangularisation
	# NOTE: Only works when the face is convex
	for i in face.size() - 2:
		var i0 = face[0]
		var i1 = face[i + 1]
		var i2 = face[i + 2]
		
		st.set_normal(normal)
		st.set_color(color)
		st.set_uv(uv[0])	
		st.add_vertex(points[i0])
		st.set_uv(uv[i + 1])
		st.add_vertex(points[i1])
		st.set_uv(uv[i + 2])
		st.add_vertex(points[i2])

	st.set_color(Color(1, 1, 1, 1))

static func brep_to_meshes(points, faces, uvs=null, st=null, color=Color(1, 1, 1, 1)):
	var meshes = []
	var st_null = st == null
	
	for face_i in faces.size():
		var face = faces[face_i]
		if st_null:
			st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			
		var uv = []
		if uvs == null:
			for i in face.size():
				uv.push_back(Vector2(0, 0))
			
		else:
			uv = uvs[face_i]
		
		_insert_brep(points, face, uv, st, color)
		
		if st_null:
			var mesh = st.commit()
			meshes.push_back(mesh)
		
	if st_null:
		return meshes
		
	else:
		return [null]	
		
static func brep_to_meshes_cont(points, faces):
	var meshes = []
	var new_points = points.duplicate()
	
	for face in faces:
		var tangents = []
		for i in face.size():
			var next_i = (i + 1) % face.size()
			
			var face_i = face[i]
			var next_face_i = face[next_i]
			
			var tangent = (points[next_face_i] - points[face_i]).normalized()

			tangents.append(tangent)
		
		# Find the contour
		const contour_width = 0.005
		var contour = []
		
		for i in tangents.size():
			var face_i = face[i]
			var point = points[face_i]
			var prev_i = (i + tangents.size() - 1) % tangents.size()
			
			var tan1 = -tangents[prev_i]
			var tan2 = tangents[i]
			
			var sin_phi = tan1.cross(tan2).length()

			var contour_point = point + contour_width * (tan1 + tan2) / sin_phi
			
			contour.append(new_points.size())
			new_points.append(contour_point)
			
		# Determine contour faces
		var contour_faces = []
		for i in face.size():
			var next_i = (i + 1) % face.size()
			
			var face_i = face[i]
			var next_face_i = face[next_i]
			
			var contour_i = contour[i]
			var next_contour_i = contour[next_i]
			
			var contour_face = [face_i, next_face_i, next_contour_i, contour_i]
			contour_faces.append(contour_face)
		
		# Build the mesh
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		brep_to_meshes(new_points, [contour], null, st)
		var contour_shade = Color(0.7, 0.65, 0.7, 1)
		brep_to_meshes(new_points, contour_faces, null, st, contour_shade)
		
		var mesh = st.commit()
		meshes.append(mesh)
		
	return meshes

static func convexhull_to_mesh(points, st=null):
	# Create faces
	var face = []
	for i in points.size():
		face.push_back(i)
		
	var uvs = null
	if points.size() == 4:
		uvs = [[Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]]
		
	return brep_to_meshes(points, [face], uvs, st)[0]

static func calculate_normal_from_points(p1, p2, p3):
	return (p1 - p2).cross(p3 - p2).normalized()
	
static func calculate_normal(points):
	return calculate_normal_from_points(points[0], points[1], points[2])
