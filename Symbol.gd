extends Node3D
class_name Symbol

@onready var _symbols = $"/root/Control/HSplitContainer/Left/RuleEditor/ToolsView/BG/SubViewportContainer/SubViewport/Root/Symbols"

var symbol
@onready var shape
@onready var poly
@onready var meshes
@onready var mesh_instances

func _ready():
	self.shape = _symbols.get_default_shape(self.symbol)
	self.poly = self.shape.get_polyhedron()
	self.meshes = self.shape.get_meshes()
	
	self.mesh_instances = []
	for mesh in self.meshes:
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = mesh
		self.add_child(mesh_instance)

func _init(_symbol : GrammarSymbol):
	self.symbol = _symbol 
