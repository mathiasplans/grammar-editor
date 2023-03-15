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
func _init(hull, _poly):
	self.normal = Geom.calculate_normal(hull)
	self.poly = _poly
	
	## Make the larger
	self.center = Geom.convex_hull_center(hull)
	
	# Get vectors to the hull points
	var hull_vec = []
	for hp in hull:
		hull_vec.push_back(hp - self.center)
		
	# Get a modified hull that is a bit bigger
	var plane_scale = 1.4
	var new_hull = []
	for i in hull.size():
		new_hull.push_back(hull[i] + (plane_scale - 1) * hull_vec[i])
		
	self.mesh = Geom.convexhull_to_mesh(new_hull)
	
	## Add a new material
	CutPlane._set_mat(self)

func _input(event):
	if event is InputEventMouseMotion:
		if not locked:
			var mousemov = Vector3(-event.relative.x, event.relative.y, 0)
			var globnorm = self.to_global(self.normal)
			globnorm.z = 0
			
			var magnitude = -mousemov.dot(globnorm)
			
			self.translate(magnitude * self.normal * 0.01)
		
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
