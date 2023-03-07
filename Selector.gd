extends Node
class_name Selector
signal face_selected(face)
signal face_deselected(face)
signal anchor_selected(anchor)
signal anchor_deselected(anchor)
signal polyhedron_selected(polyhedron)
signal polyhedron_deselected(polyhedron)

onready var anchor_manager = $"../AnchorManager"

# Different modes and their order
enum {MODE_NONE, MODE_FACE, MODE_ANCHOR, MODE_POLY, MODE_amount}

var current = null
var current_mode = MODE_FACE

var change_direction = 1

var enabled = true

var anchor_move = null

func _ready():
	pass
	
func _select_none_action(face):
	pass
	
func _deselect_none_action(face):
	pass
	
func _select_face_action(face):
	if self.anchor_move != null:
		var poly = face.poly
		self.anchor_manager.move_face(poly, face.face_i)
		self.select_anchor(poly.get_first_face_obj())
		
	else:	
		face.select()
		self.emit_signal("face_selected", face)
	
func _deselect_face_action(face):
	face.deselect()
	self.emit_signal("face_deselected", face)
	
func _select_anchor_action(face):
	self.anchor_manager.select(face.poly)
	
func _deselect_anchor_action(face):
	self.anchor_manager.deselect(face.poly)
	
func _select_poly_action(face):
	face.select(true)
	self.emit_signal("polyhedron_selected", face.poly)
	
func _deselect_poly_action(face):
	face.deselect(true)
	self.emit_signal("polyhedron_deselected", face.poly)
	
const select_action = ["_select_none_action", "_select_face_action", "_select_anchor_action", "_select_poly_action"]
const deselect_action = ["_deselect_none_action", "_deselect_face_action", "_deselect_anchor_action", "_deselect_poly_action"]

func _select_action_call():
	#print(self.current, " selects   ", self.current_mode)
	if self.current != null:
		assert(self.current_mode < MODE_amount)
		self.call(self.select_action[self.current_mode], self.current)
		
	# End the anchor move procedure
	self.anchor_move = null
	
func _deselect_action_call():
	#print(self.current, " deselects ", self.current_mode)
	if self.current != null:
		assert(self.current_mode < MODE_amount)
		self.call(self.deselect_action[self.current_mode], self.current)

func select(face):
	if not self.enabled:
		return
		
	self._deselect_action_call()
	
	if face != self.current:
		self.current = face
		current_mode = MODE_NONE
		
	# Progress current mode
	self.current_mode += change_direction
	
	if self.current_mode == MODE_ANCHOR and (face.poly.symbol == null or face.poly.original or face.face_i != 0):
		self.current_mode += change_direction
		
	# Overflow
	self.current_mode = (self.current_mode + MODE_amount) % MODE_amount
	
	self._select_action_call()
	
func _same_mode(face, mode):
	return face == self.current and mode == self.current_mode
	
func _same_mode_poly(face, mode):
	return self.current != null and face.poly == self.current.poly and mode == self.current_mode
	
func select_clear(face=null):
	if self.enabled and not _same_mode(face, MODE_NONE):
		self._deselect_action_call()
		
		self.current = face
		current_mode = MODE_NONE
		
		self._select_action_call()

func select_face(face):
	if self.enabled and not _same_mode(face, MODE_FACE):
		self._deselect_action_call()
		
		self.current = face
		current_mode = MODE_FACE
		
		self._select_action_call()
		
func select_anchor(face):
	if self.enabled and not _same_mode(face, MODE_ANCHOR):
		self._deselect_action_call()
		
		self.current = face
		current_mode = MODE_ANCHOR
		
		self._select_action_call()
	
func select_poly(face):
	if self.enabled and not _same_mode_poly(face, MODE_POLY):
		self._deselect_action_call()
		
		self.current = face
		current_mode = MODE_POLY
		
		self._select_action_call()
		
func _input(event):
	if event is InputEventKey:
		# Clear the selection on escape
		if event.pressed and event.scancode == KEY_ESCAPE:
			self.select_clear()
			
		# Make the reverse changing possible
		if event.scancode == KEY_SHIFT:
			if event.pressed:
				self.change_direction = -1
				
			else:
				self.change_direction = 1
				
		if self.current_mode == MODE_ANCHOR:
			if event.pressed and event.scancode == KEY_COMMA:
				var poly = self.current.poly
				self.select_clear()
				self.anchor_manager.rotate_left(poly)
				
				# Reselect
				self.select_anchor(poly.get_first_face_obj())
				
			elif event.pressed and event.scancode == KEY_PERIOD:
				var poly = self.current.poly
				self.select_clear()
				self.anchor_manager.rotate_right(poly)
				
				# Reselect
				self.select_anchor(poly.get_first_face_obj())
				
			elif event.pressed and event.scancode == KEY_M:
				self.anchor_move = self.current.poly
				
func enable():
	self.enabled = true
	
func disable():
	self.select_clear()
	self.enabled = false
