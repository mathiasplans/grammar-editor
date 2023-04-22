extends Node3D
class_name Cursors

signal create_cut(cut_plane, poly)

var mode = Mode.NONE

@onready var cursors = [$Cursor1, $Cursor2, $Cursor3]
var cursor_i = 0
var cursor_polys = [null, null, null]

var complete = false
var poly

func _ready():	
	%ToolOpt.mode_changed.connect(_on_mode_change)
	
func _on_mode_change(_mode, _old_mode):
	# End function for current mode
	self.end_functions[self.mode].call()
	
	# Change the mode
	self.mode = _mode
	
	# Start function for the new mode
	self.start_functions[self.mode].call()
	
func none_start():
	pass
	
func none_end():
	pass
		
func face_start():
	pass
	
func face_end():
	pass
		
func tripoint_start():
	self.complete = false
	self.activate_cursors()
	%Editor/Selector.disable()
		
func tripoint_end():
	self.disable_cursors()
	%Editor/Selector.enable()
	
func test_start():
	pass
	
func test_end():
	pass
	
func prism_start():
	pass
	
func prism_end():
	pass
	
func multi_start():
	pass
	
func multi_end():
	pass
	
var start_functions = {
	Mode.NONE:            none_start,
	Mode.TEST:            test_start,
	Mode.FACE_CUT:        face_start,
	Mode.TRI_POINT_CUT:   tripoint_start,
	Mode.PRISM_CUT:       prism_start,
	Mode.MULTI_CUT:       multi_start
}

var end_functions = {
	Mode.NONE:            none_end,
	Mode.TEST:            test_end,
	Mode.FACE_CUT:        face_end,
	Mode.TRI_POINT_CUT:   tripoint_end,
	Mode.PRISM_CUT:       prism_end,
	Mode.MULTI_CUT:       multi_end
}

func end_current_mode():
	%ToolOpt.end_mode()

func _input(event):
	if event is InputEventMouseMotion:
		if self.mode == Mode.TRI_POINT_CUT and not complete:
			self.closest_to_mouse()
			
	if event is InputEventKey:
		if event.keycode == KEY_SHIFT and self.mode == Mode.TRI_POINT_CUT and not complete:
			self.closest_to_mouse()
		
	if event is InputEventMouseButton:
		if self.mode == Mode.TRI_POINT_CUT:
			if event.pressed:
				if event.button_index == MOUSE_BUTTON_RIGHT:
					if self.poly == null:
						self.poly = self.get_poly()
					
					self.complete = self.next_cursor()
					
					if self.complete:
						self.on_tripointcut_complete()
						self.end_current_mode()
					
				#elif event.button_index == MOUSE_BUTTON_RIGHT:
				#	self.complete = false
				#	if self.prev_cursor():
				#		self.poly = null
		
func activate_cursors():
	self.poly = null
	self.cursor_i = 0
	self.cursors[cursor_i].visible = true
	self.closest_to_mouse()
	
func next_cursor():
	if self.cursor_i + 1 < self.cursors.size():
		self.cursor_i += 1
		self.cursors[self.cursor_i].visible = true
		self.closest_to_mouse()
		return false
		
	else:
		return true
		
func prev_cursor():
	if self.cursor_i > 0:
		self.cursors[self.cursor_i].visible = false
		self.cursor_i -= 1
		self.closest_to_mouse()
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
	var viewport = self.get_viewport()
	var cam = viewport.get_camera_3d()
	if %RuleManager.current_rule != null:
		var mouse_position = viewport.get_mouse_position()

		var polys = %RuleManager.get_polyhedrons()
		var closest_dist = 10000000000
		var closest_p
		var closest_poly
		
		for _poly in polys:
			# Get the closest edge and point
			var closeness
			if Input.is_key_pressed(KEY_SHIFT):
				closeness = _poly.get_closest_vertex(mouse_position, self.global_transform, cam, true)
				
			else:
				var snap_to_grid = 0
				if Input.is_key_pressed(KEY_CTRL):
					snap_to_grid = 0.1
					
				closeness = _poly.get_closest_edge(mouse_position, self.global_transform, cam, true, snap_to_grid)
				
			var dist = closeness[0]
			if dist < closest_dist:
				closest_dist = dist
				closest_p = closeness[1]
				closest_poly = _poly
		
		if closest_p != null:
			self.cursors[self.cursor_i].position = closest_p
			self.cursor_polys[self.cursor_i] = closest_poly
			
func add_cuts(cuts, _poly):
	self.create_cut.emit(cuts, _poly)

func on_tripointcut_complete():
	var cut_plane = CutPlane.from_hull(null, self.get_hull(), Mode.TRI_POINT_CUT)
	self.create_cut.emit([cut_plane], null)
	
func get_multicut_nr():
	return %ToolOpt/MultiCutOpt/SpinBox.value
