extends MeshInstance3D
class_name CutPlane
signal cut_complete(cut_plane, poly)

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var normal : Vector3
var dir : Vector3
var locked = false
var poly = null
var center : Vector3
var other_center : Vector3
var delete = false
var fixed_translation = Vector3(0, 0, 0)
var hull

var cut_mode = Mode.NONE

var cutMat = preload("res://mats/cut.tres")

# Gets a point on the plane
func point():
	return self.mesh.get_faces()[0] + self.fixed_translation
	
func _init(_mode):
	self.cut_mode = _mode
	
func _set_mat():
	self.material_override = self.cutMat

static func _hull_to_cutplane(new_plane, _hull):
	var hull_vec = []
	for hp in _hull:
		hull_vec.push_back(hp - new_plane.center)
		
	# Get a modified hull that is a bit bigger
	var plane_scale = 1.4
	var new_hull = []
	for i in _hull.size():
		new_hull.push_back(plane_scale * hull_vec[i])
		
	new_plane.mesh = Geom.convexhull_to_mesh(new_hull)
	new_plane.position = new_plane.center
	
	new_plane.fixed_translation = new_plane.position
	
	new_plane.hull = _hull
	
	## Add a new material
	new_plane._set_mat()
	
	return new_plane

static func from_hull(_poly, _hull, _cut_mode):
	var new_plane = CutPlane.new(_cut_mode)
	
	new_plane.normal = Geom.calculate_normal(_hull)
	new_plane.poly = _poly
	new_plane.center = Geom.convex_hull_center(_hull)
	new_plane.dir = new_plane.normal
	
	return _hull_to_cutplane(new_plane, _hull)

static func from_face(_poly, face_i, _cut_mode):
	var new_plane = CutPlane.new(_cut_mode)
	
	new_plane.normal = _poly.face_normal(face_i)
	new_plane.poly = _poly
	new_plane.center = _poly.face_centroid(face_i)
	
	if _cut_mode == Mode.PRISM_CUT or _cut_mode == Mode.MULTI_CUT:
		var other_i = _poly.get_prism_base(face_i)
		
		if other_i != null:
			new_plane.other_center = _poly.face_centroid(other_i)
			var from_other = new_plane.other_center - new_plane.center
			new_plane.dir = from_other.normalized()
		
		else:
			new_plane.free()
			return null
		
	else:
		new_plane.dir = new_plane.normal
	
	# Get vectors to the hull points
	var _hull = _poly.get_hull(face_i)
	return _hull_to_cutplane(new_plane, _hull)
	
func closest_to_mouse():
	var parent_transform = self.get_parent_node_3d().global_transform
	
	var viewport = self.get_viewport()
	var cam = viewport.get_camera_3d()
	var mouse_position = viewport.get_mouse_position()
	
	var cut_plane_a = parent_transform * (self.center + self.dir * 10000)
	var cut_plane_b = parent_transform * (self.center - self.dir * 10000)
	
	var p1 = cam.unproject_position(cut_plane_a)
	var p2 = cam.unproject_position(cut_plane_b)
	var screen_position = Geometry2D.get_closest_point_to_segment_uncapped(mouse_position, p1, p2)
	var screen_origin = cam.project_ray_origin(screen_position)
	var screen_end = screen_origin + cam.project_ray_normal(screen_position) * 100000
	
	var closest_points = Geometry3D.get_closest_points_between_segments(screen_origin, screen_end, cut_plane_a, cut_plane_b)
	var cp = parent_transform.inverse() * closest_points[0]
	
	# Snap to grid
	if self.cut_mode == Mode.PRISM_CUT and Input.is_key_pressed(KEY_CTRL):
		var from_other = self.other_center - self.center
		var from_other_len = from_other.length()
		var grid_len = from_other_len / 10
		
		var to_cp = self.center - cp
		var to_cp_len = to_cp.length()
		
		var reminder = fmod(to_cp_len, grid_len)
		var intended_len = to_cp_len - reminder
		if reminder > grid_len / 2:
			intended_len += grid_len
			
		var new_to_cp = to_cp.normalized() * intended_len
		
		cp = self.center - new_to_cp
			
	return cp
	
func prism_move_at(p):
	if self.cut_mode == Mode.PRISM_CUT or self.cut_mode == Mode.MULTI_CUT:
		var a = self.center
		var b = self.other_center
		
		var ab = b - a
		var x = p * ab
		
		self.fixed_translation = a + x
	
func complete(_emit_signal=true):
	if not locked:
		locked = true
		self.fixed_translation = self.position

		if _emit_signal:
			self.cut_complete.emit([self], self.poly)
		
		self.queue_free()
	
func _input(event):
	if event is InputEventMouseMotion:
		if not locked:
			var pos = closest_to_mouse()
			self.position = pos
		
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				self.complete()
