extends MeshInstance3D
class_name Face

signal create_cut(cut_plane)

var howerMaterial = null
var selectedMaterial = null
var howerselectedMaterial = null
var in_area = false
var selected = false
var poly = null
var hull = null
var hull_indices = null
var cut_plane_exists = false
var outline
var normal = null
var face_i

@onready var selector = $"/root/Control/HSplitContainer/Left/SubViewportContainer/SubViewport/Root/Editor/Selector"

const cut_key = KEY_C
const cutplane_script = preload("res://CutPlane.gd")
const shader = preload("res://face.gdshader")

func create_better_outline(margin):
	var center = Geom.convex_hull_center(self.hull)
	
	var front_fake = []
	var back = []
	for h in self.hull:
		var to_h = (h - center).normalized()
		back.push_back(h + margin * to_h - 0.00005 * self.normal)
		front_fake.push_back(h + margin * to_h + 0.00005 * self.normal)
		
	var front = front_fake.duplicate()
	front.reverse()
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(0.8, 0.8, 1.0, 1.0))
	
	Geom.convexhull_to_mesh(front, st)
	Geom.convexhull_to_mesh(back, st)
	
	return st.commit()

func _init(_mesh,_poly,_hull_indices,_face_i):
	self.mesh = _mesh
	self.poly = _poly
	self.hull_indices = _hull_indices
	self.face_i = _face_i
	
	self.hull = []
	for hi in _hull_indices:
		self.hull.push_back(_poly.vertices[hi])
		
	self.normal = (self.hull[0] - self.hull[1]).cross(self.hull[2] - self.hull[1]).normalized()
	
	var marginMat = StandardMaterial3D.new()
	marginMat.albedo_color = Color(0.8, 0.8, 1.0, 1.0)
	marginMat.flags_unshaded = true
	
	var outline_mesh = self.create_better_outline(0.012)
	self.outline = MeshInstance3D.new()
	self.outline.visible = false
	self.outline.mesh = outline_mesh
	self.outline.material_override = marginMat
	
	self.add_child(self.outline)
	
	# Add to group
	self.add_to_group(self.poly.to_string())

# Called when the node enters the scene tree for the first time.
func _ready():
	var _con1 = $Area3D.connect("mouse_entered",Callable(self,"_on_area_enter"))
	var _con2 = $Area3D.connect("mouse_exited",Callable(self,"_on_area_exit"))
	var _con3 = $Area3D.connect("input_event",Callable(self,"_on_area_input_event"))

	# Create a new materials
	howerMaterial = StandardMaterial3D.new()
	howerMaterial.albedo_color = Color(1.0, 0.0, 0.0, 1.0)
	#howerMaterial.gdshader = self.gdshader
	
	selectedMaterial = StandardMaterial3D.new()
	selectedMaterial.albedo_color = Color(0.0, 1.0, 0.0, 1.0)
	
	howerselectedMaterial = StandardMaterial3D.new()
	howerselectedMaterial.albedo_color = Color(0.7, 0.7, 0.2, 1.0)
	
func disable_collision():
	$Area3D.visible = false
	
func enable_collision():
	$Area3D.visible = true
	
func get_color():
	if self.in_area:
		if self.selected:
			return self.howerselectedMaterial
			
		else:
			return self.howerMaterial
			
	else:
		if self.selected:
			return self.selectedMaterial
			
		else:
			return null

func emphasize():
	if not self.in_area:
		self.in_area = true
		self.material_override = self.get_color()
	
func deemphasize():
	if self.in_area:
		self.in_area = false
		self.material_override = self.get_color()
	
func select(all_in_poly=false):
	if all_in_poly:
		self.get_tree().call_group(self.poly.to_string(), "select")
		
	elif not self.selected:
		self.selected = true
		self.outline.visible = true
		self.material_override = self.get_color()
	
func deselect(all_in_poly=false):
	if all_in_poly:
		self.get_tree().call_group(self.poly.to_string(), "deselect")
		
	elif self.selected:
		self.selected = false
		self.outline.visible = false
		self.material_override = self.get_color()

func _on_area_enter():
	if self.selector.enabled:
		self.emphasize()
	
func _on_area_exit():
	self.deemphasize()
	
func _input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			if self.in_area:
				self.selector.select(self)

	if event is InputEventKey:
		# Create a cutting plane from selected face
		if self.selected:
			if event.pressed:
				if self.selector.current_mode == Selector.Mode.FACE and event.keycode == cut_key:
					# Make sure that a cutting plane doesn't exist already
					if not self.cut_plane_exists:
						var cut_plane = CutPlane.new(self.hull, self.poly)
						
						cut_plane.connect("cut_complete",Callable(self,"_on_cut_complete"))
						
						self.cut_plane_exists = true
						self.create_cut.emit(cut_plane)
						
						self.selector.disable()
						self.deemphasize()
				
func _on_cut_complete(_cut_plane):
	self.cut_plane_exists = false
	self.selector.enable()

func _on_area_input_event(_camera, _event, _click_position, _click_normal, _shape_idx):
	pass

func set_anchor(_anchor):
	if self.anchor != null:
		self.anchor.queue_free()
		
	self.anchor = _anchor
	self.add_child(self.anchor)
