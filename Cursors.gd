extends Node3D
class_name Cursors

signal create_cut(cut_plane)

enum Mode {NONE, FACE_CUT, TRI_POINT_CUT}
var mode : Mode = Mode.FACE_CUT

@onready var cursors = [$Cursor1, $Cursor2, $Cursor3]
var cursor_i = 0
var cursor_polys = [null, null, null]

var complete = false
var poly

func _ready():
	%ToolInfo/FaceCut.toggled.connect(_on_facecut_toggled)
	%ToolInfo/TriPointCut.toggled.connect(_on_tripointcut_toggled)

func _on_facecut_toggled(pressed):
	if pressed:
		self.mode = Mode.FACE_CUT

func _on_tripointcut_toggled(pressed):
	if pressed:
		self.mode = Mode.TRI_POINT_CUT
		self.activate_cursors()
		
		%Editor/Selector.disable()
		
	else:
		self.tripointcut_end()
		
func tripointcut_end():
	%ToolInfo/TriPointCut.button_pressed = false
	self.disable_cursors()
	%Editor/Selector.enable()
	self.mode = Mode.NONE

func _input(event):
	if event is InputEventMouseMotion:
		if self.mode == Mode.TRI_POINT_CUT and not complete:
			self.closest_to_mouse()
		
	if event is InputEventMouseButton:
		if self.mode == Mode.TRI_POINT_CUT:
			if event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					if self.poly == null:
						self.poly = self.get_poly()
					
					self.complete = self.next_cursor()
					
					if self.complete:
						self.on_tripointcut_complete()
						self.tripointcut_end()
					
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					self.complete = false
					if self.prev_cursor():
						self.poly = null
		
func activate_cursors():
	self.poly = null
	self.cursor_i = 0
	self.cursors[cursor_i].visible = true
	self.closest_to_mouse()
	
func next_cursor():
	if self.cursor_i + 1 < self.cursors.size():
		self.cursor_i += 1
		self.cursors[self.cursor_i].visible = true
		return false
		
	else:
		return true
		
func prev_cursor():
	if self.cursor_i > 0:
		self.cursors[self.cursor_i].visible = false
		self.cursor_i -= 1
		return false
		
	else:
		return true
		
func disable_cursors():
	for cursor in self.cursors:
		cursor.visible = false
		
	self.poly = null
		
func get_poly():
	return self.cursor_polys[self.cursor_i]
	
func get_hull():
	var hull = []
	for cursor in self.cursors:
		hull.push_back(cursor.position)
		
	return hull

func closest_to_mouse():
	if %RuleManager.current_rule != null:
		var mouse_position = self.get_viewport().get_mouse_position()
		var ray_origin = %Cam.project_ray_origin(mouse_position)
		var ray_end = ray_origin + %Cam.project_ray_normal(mouse_position) * 100

		var polys = %RuleManager.get_polyhedrons()
		var closest_dist = 10000000000
		var closest_p
		var closest_poly
		
		for poly in polys:
			# Get the closest edge and point
			var closeness
			if Input.is_key_pressed(KEY_SHIFT):
				closeness = poly.get_closest_vertex(ray_origin, ray_end, self.global_transform, true)
				
			else:
				closeness = poly.get_closest_edge(ray_origin, ray_end, self.global_transform, true)
				
			var dist = closeness[0]
			if dist < closest_dist:
				closest_dist = dist
				closest_p = closeness[1]
				closest_poly = poly
		
		if closest_p != null:
			self.cursors[self.cursor_i].position = closest_p
			self.cursor_polys[self.cursor_i] = closest_poly

func on_tripointcut_complete():
	var cut_plane = CutPlane.new(self.get_hull(), self.poly)
	self.create_cut.emit(cut_plane)
