extends HSplitContainer
class_name ToolOpt

signal mode_changed(mode, from)

var mode = Mode.NONE

@onready var mode_to_child = {
	Mode.FACE_CUT: $FaceCutOpt,
	Mode.TRI_POINT_CUT: $TriPointCutOpt,
	Mode.TEST: $TestOpt,
	Mode.PRISM_CUT: $PrismCutOpt,
	Mode.MULTI_CUT: $MultiCutOpt
}

func _ready():
	%ToolInfo/FaceCut.pressed.connect(_on_facecut_press)
	%ToolInfo/TriPointCut.pressed.connect(_on_tripointcut_press)
	%ToolInfo/PrismCut.pressed.connect(_on_prismcut_press)
	%ToolInfo/MultiCut.pressed.connect(_on_multicut_press)
	
	%RuleOpt/TestGrammar.pressed.connect(_on_testgrammar_press)
	
func _on_facecut_press():
	self.set_mode(Mode.FACE_CUT)
	
func _on_tripointcut_press():
	self.set_mode(Mode.TRI_POINT_CUT)
	
func _on_prismcut_press():
	self.set_mode(Mode.PRISM_CUT)
	
func _on_testgrammar_press():
	if self.mode == Mode.TEST:
		self.set_mode(Mode.NONE)
		
	else:
		self.set_mode(Mode.TEST)
		
func _on_multicut_press():
	self.set_mode(Mode.MULTI_CUT)
		
func end_mode():
	self.set_mode(Mode.NONE)

func set_mode(_mode):
	# Disable old
	if self.mode != Mode.NONE:
		var child = self.mode_to_child[self.mode]
		child.visible = false
	
	# Enable new
	if _mode != Mode.NONE:
		var child = self.mode_to_child[_mode]
		child.visible = true
	
	var old_mode = self.mode
	self.mode = _mode
	
	self.mode_changed.emit(self.mode, old_mode)
