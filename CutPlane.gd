extends MeshInstance3D
class_name CutPlane
signal cut_complete(cut_plane)

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var normal : Vector3
var locked = false
var poly = null
var center : Vector3
var delete = false
var fixed_translation = Vector3(0, 0, 0)

# Gets a point on the plane
func point():
	return self.mesh.get_faces()[0] + self.fixed_translation
	
static func _set_mat(mesh_inst, double_alpha=false):
	var alpha = 0.3
	if double_alpha:
		alpha = alpha / 2
	
	mesh_inst.material_override = StandardMaterial3D.new()
	mesh_inst.material_override.params_cull_mode = StandardMaterial3D.CULL_DISABLED
	mesh_inst.material_override.albedo_color = Color(1.0, 0.5, 0.0, alpha)
	mesh_inst.material_override.flags_transparent = true

# Constructor
func _init(_poly, face_i):
	self.normal = _poly.face_normal(face_i)
	self.poly = _poly
	
	## Make the larger
	self.center = _poly.face_centroid(face_i)
	
	# Get vectors to the hull points
	var hull = _poly.get_hull(face_i)
	var hull_vec = []
	for hp in hull:
		hull_vec.push_back(hp - self.center)
		
	# Get a modified hull that is a bit bigger
	var plane_scale = 1.4
	var new_hull = []
	for i in hull.size():
		new_hull.push_back(plane_scale * hull_vec[i])
		
	self.mesh = Geom.convexhull_to_mesh(new_hull)
	self.position = self.center
	
	## Add a new material
	CutPlane._set_mat(self)
	
func closest_to_mouse():
	var parent_transform = self.get_parent_node_3d().global_transform
	
	var viewport = self.get_viewport()
	var cam = viewport.get_camera_3d()
	var mouse_position = viewport.get_mouse_position()
	var ray_origin = cam.project_ray_origin(mouse_position)
	var ray_end = ray_origin + cam.project_ray_normal(mouse_position) * 10000
	
	var cut_plane_a = parent_transform * (self.center + self.normal * 10000)
	var cut_plane_b = parent_transform * (self.center - self.normal * 10000)
	
	var p1 = cam.unproject_position(cut_plane_a)
	var p2 = cam.unproject_position(cut_plane_b)
	var screen_position = Geometry2D.get_closest_point_to_segment_uncapped(mouse_position, p1, p2)
	var screen_origin = cam.project_ray_origin(screen_position)
	var screen_end = screen_origin + cam.project_ray_normal(screen_position) * 100000
	
	var closest_points = Geometry3D.get_closest_points_between_segments(screen_origin, screen_end, cut_plane_a, cut_plane_b)
	return parent_transform.inverse() * closest_points[0]
	
func _input(event):
	if event is InputEventMouseMotion:
		if not locked:
			var pos = closest_to_mouse()
			self.position = pos
		
	if event is InputEventMouseButton:
		if event.pressed:
			if not locked:
				locked = true
				self.fixed_translation = self.position
				
				# Create a copy
				var copy_mesh = MeshInstance3D.new()
				copy_mesh.mesh = self.mesh
				CutPlane._set_mat(copy_mesh, true)
				CutPlane._set_mat(self, true)
												
				# Translate the plane a bit to prevent z-fight
				var z_fight_mag = 0.001
				copy_mesh.translate(self.normal * z_fight_mag * 2)
				self.translate(-self.normal * z_fight_mag)
				
				self.add_child(copy_mesh)
				
				self.cut_complete.emit(self)
				
				# Some receiver set the flag to delete the object
				if self.delete:
					self.queue_free()
