extends Node
class_name Geom

static func create_quad(corners):
	var verts = corners
	var normal = Normals.calculate_normal(corners)
	var normals = [normal, normal, normal, normal]
	var uvs = [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
	var colors = [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]
	var indices = [0, 1, 2, 2, 3, 0]
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(verts)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(uvs)
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray(colors)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(indices)
	
	# Turn the quad into a mesh
	var face = ArrayMesh.new()
	face.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return face
		
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

static func brep_to_meshes(points, faces, uvs=null, st=null):
	var meshes = []
	var st_null = st == null
	
	for face_i in faces.size():
		var face = faces[face_i]
		if st_null:
			st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
		
		var normal = calculate_normal_from_points(
			points[face[0]],
			points[face[1]],
			points[face[2]]
		)
		
		var uv = []
		if uvs == null:
			for i in face.size():
				uv.push_back(Vector2(0, 0))
			
		else:
			uv = uvs[face_i]
			
		# Triangularisation
		# NOTE: Only works when the face is convex
		for i in face.size() - 2:
			var i0 = face[0]
			var i1 = face[i + 1]
			var i2 = face[i + 2]
			
			st.set_normal(normal)
			st.set_uv(uv[0])	
			st.add_vertex(points[i0])
			st.set_uv(uv[i + 1])
			st.add_vertex(points[i1])
			st.set_uv(uv[i + 2])
			st.add_vertex(points[i2])
			
		if st_null:
			var mesh = st.commit()
			meshes.push_back(mesh)
		
	if st_null:
		return meshes
		
	else:
		return [null]

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
