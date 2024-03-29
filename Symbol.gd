extends Node3D
class_name Symbol

@onready var _symbols = $"/root/Control/HSplitContainer/Left/RuleEditor/ToolsView/BG/SVC/SV/Root/Symbols"

var symbol
@onready var shape
@onready var poly
@onready var meshes
@onready var mesh_instances

func _ready():
	self.shape = _symbols.get_default_shape(self.symbol)
	self.poly = GB.get_polyhedron(self.shape)
	self.meshes = GB.get_meshes(self.shape)
	
	self.mesh_instances = []
	for mesh in self.meshes:
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = mesh
		self.add_child(mesh_instance)
		
		self.mesh_instances.append(mesh_instance)

func _init(_symbol : GrammarSymbol):
	self.symbol = _symbol 
	
func add_reference_anchor(anchor):
	self.add_child(anchor)
