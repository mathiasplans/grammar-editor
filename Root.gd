extends Node3D

@onready var apply_rule = %ToolOpt/TestOpt/ApplyRule

const ROT_SPEED = 0.01
var mouse_down = false

func _ready():
	%ToolOpt.mode_changed.connect(self._on_mode_change)
	
func _input(event):
	# Camera rotation
	if event is InputEventMouseButton:
		self.mouse_down = event.is_pressed()
		
	if event is InputEventMouseMotion:
		if self.mouse_down:
			self.rotate(Vector3.UP, event.relative.x * ROT_SPEED)
			self.rotate(Vector3.RIGHT, event.relative.y * ROT_SPEED)

func _on_mode_change(_mode, _old_mode):
	if _mode == _old_mode:
		pass
		
	elif _old_mode == Mode.TEST:
		$Editor.visible = true
		$Tester.visible = false
	
	elif _mode == Mode.TEST:
		# Swap visiblilities
		$Editor.visible = false
		$Tester.visible = true
