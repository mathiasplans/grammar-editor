extends Node
class_name Selector
signal face_selected(face)
signal face_deselected(face)
signal anchor_selected(anchor)
signal anchor_deselected(anchor)
signal polyhedron_selected(polyhedron)
signal polyhedron_deselected(polyhedron)

@onready var anchor_manager = $"../AnchorManager"

# Different modes and their order
enum Mode {NONE, FACE, ANCHOR, POLY, _amount}

var current = null
var current_mode : Mode = Mode.FACE

var change_direction = 1

var enabled = true

var anchor_move = null

var nosig_sel = false
var nosig_desel = false

func _ready():
	pass
	
func _select_none_action(_face, _rule):
	pass
	
func _deselect_none_action(_face, _rule):
	pass
	
func _select_face_action(face, rule):
	if self.anchor_move != null:
		var poly = face.poly
		self.anchor_manager.move_face(poly, face.face_i)
		self.select_anchor(poly.get_first_face_obj(), rule)
		
	else:	
		face.select()
		
		if not self.nosig_sel:
			self.face_selected.emit(face, rule)
	
func _deselect_face_action(face, rule):
	face.deselect()
	
	if not self.nosig_desel:
		self.face_deselected.emit(face, rule)
	
func _select_anchor_action(face, rule):
	self.anchor_manager.select(face.poly, rule)
	
	if not self.nosig_sel:
		self.anchor_selected.emit(face, rule)
	
func _deselect_anchor_action(face, rule):
	self.anchor_manager.deselect(face.poly, rule)
	
	if not self.nosig_desel:
		self.anchor_deselected.emit(face, rule)
	
func _select_poly_action(face, rule):
	face.select(true)
	
	if not self.nosig_sel:
		self.polyhedron_selected.emit(face.poly, rule)
	
func _deselect_poly_action(face, rule):
	face.deselect(true)
	
	if not self.nosig_desel:
		self.polyhedron_deselected.emit(face.poly, rule)
	
const select_action = ["_select_none_action", "_select_face_action", "_select_anchor_action", "_select_poly_action"]
const deselect_action = ["_deselect_none_action", "_deselect_face_action", "_deselect_anchor_action", "_deselect_poly_action"]

func _select_action_call(rule):
	#print(self.current, " selects   ", self.current_mode)
	if self.current != null:
		assert(self.current_mode < Mode._amount)
		self.call(self.select_action[self.current_mode], self.current, rule)
		
	# End the anchor move procedure
	self.anchor_move = null
	self.nosig_sel = false
	
func _deselect_action_call(rule):
	#print(self.current, " deselects ", self.current_mode)
	if self.current != null:
		assert(self.current_mode < Mode._amount)
		self.call(self.deselect_action[self.current_mode], self.current, rule)
		
	self.nosig_desel = false

func select(face, rule=%RuleManager.current_rule):
	if not self.enabled:
		return
		
	self._deselect_action_call(rule)
	
	if face != self.current:
		self.current = face
		current_mode = Mode.NONE
		
	# Progress current mode
	self.current_mode = (self.current_mode + change_direction) as Mode 
	
	if self.current_mode == Mode.ANCHOR and (face.poly.symbol == null or face.poly.original or face.face_i != 0):
		self.current_mode = (self.current_mode + change_direction) as Mode 
		
	# Overflow
	self.current_mode = ((self.current_mode + Mode._amount) % Mode._amount) as Mode
	
	self._select_action_call(rule)
	
func _same_mode(face, mode):
	return face == self.current and mode == self.current_mode
	
func _same_mode_poly(face, mode):
	return self.current != null and face.poly == self.current.poly and mode == self.current_mode
	
func select_clear(face=null, rule=%RuleManager.current_rule):
	if self.enabled and not _same_mode(face, Mode.NONE):
		self._deselect_action_call(rule)
		
		self.current = face
		current_mode = Mode.NONE
		
		self._select_action_call(rule)

func select_face(face, rule=%RuleManager.current_rule):
	if self.enabled and not _same_mode(face, Mode.FACE):
		self._deselect_action_call(rule)
		
		self.current = face
		current_mode = Mode.FACE
		
		self._select_action_call(rule)
		
func select_anchor(face, rule=%RuleManager.current_rule):
	if self.enabled and not _same_mode(face, Mode.ANCHOR):
		self._deselect_action_call(rule)
		
		self.current = face
		current_mode = Mode.ANCHOR
		
		self._select_action_call(rule)
	
func select_poly(face, rule=%RuleManager.current_rule):
	if self.enabled and not _same_mode_poly(face, Mode.POLY):
		self._deselect_action_call(rule)
		
		self.current = face
		current_mode = Mode.POLY
		
		self._select_action_call(rule)
		
func no_select_signal():
	self.nosig_sel = true
	
func no_deselect_signal():
	self.nosig_desel = true
		
func _input(event):
	if event is InputEventKey:
		# Clear the selection on escape
		if event.pressed and event.keycode == KEY_ESCAPE:
			self.select_clear()
			
		# Make the reverse changing possible
		if event.keycode == KEY_SHIFT:
			if event.pressed:
				self.change_direction = -1
				
			else:
				self.change_direction = 1
				
		if self.current_mode == Mode.ANCHOR:
			if event.pressed and event.keycode == KEY_COMMA:
				var poly = self.current.poly
				self.select_clear()
				self.anchor_manager.rotate_left(poly)
				
				# Reselect
				self.select_anchor(poly.get_first_face_obj())
				
			elif event.pressed and event.keycode == KEY_PERIOD:
				var poly = self.current.poly
				self.select_clear()
				self.anchor_manager.rotate_right(poly)
				
				# Reselect
				self.select_anchor(poly.get_first_face_obj())
				
			elif event.pressed and event.keycode == KEY_M:
				self.anchor_move = self.current.poly
				
func enable():
	self.enabled = true
	
func disable():
	self.select_clear()
	self.enabled = false
