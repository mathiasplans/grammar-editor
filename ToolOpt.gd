extends HSplitContainer
class_name ToolOpt

enum Mode {NONE, FACE_CUT, TRI_POINT_CUT, TEST, PRISM_CUT}
var mode : Mode = Mode.NONE
@onready var mode_to_child = {
	Mode.FACE_CUT: $FaceCutOpt,
	Mode.TRI_POINT_CUT: $TriPointCutOpt,
	Mode.TEST: $TestOpt,
	Mode.PRISM_CUT: $PrismCutOpt
}

func set_mode(_mode : Mode):
	# Disable old
	if self.mode != Mode.NONE:
		var child = self.mode_to_child[self.mode]
		child.visible = false
	
	# Enable new
	if _mode != Mode.NONE:
		var child = self.mode_to_child[_mode]
		child.visible = true
		
	self.mode = _mode
