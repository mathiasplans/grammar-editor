extends Node3D

@onready var test_grammar = %RuleOpt/TestGrammar
@onready var apply_rule = %ToolOpt/TestOpt/ApplyRule

const ROT_SPEED = 0.01
var mouse_down = false

func _ready():
	self.test_grammar.button_down.connect(self._on_test_grammar_press)
	
func _input(event):
	# Camera rotation
	if event is InputEventMouseButton:
		self.mouse_down = event.is_pressed()
		
	if event is InputEventMouseMotion:
		if self.mouse_down:
			self.rotate(Vector3.UP, event.relative.x * ROT_SPEED)
			self.rotate(Vector3.RIGHT, event.relative.y * ROT_SPEED)

# Hide children and 
func _on_test_grammar_press():
	# Swap visiblilities
	$Editor.visible = not $Editor.visible
	$Tester.visible = not $Tester.visible
	
	# Toggle the ability of the generation button
	self.apply_rule.disabled = not self.apply_rule.disabled
	
	if $Editor.visible != true:
		%ToolOpt.set_mode(ToolOpt.Mode.TEST)
		
	else:
		%ToolOpt.set_mode(ToolOpt.Mode.NONE)
