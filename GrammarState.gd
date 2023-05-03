@tool

extends Resource
class_name GrammarState

# Grammar configuration
@export var grammar : Grammar:
	set(gr):
		grammar = gr
		
		if gr != null:
			initial_symbol = 0
		
		self.notify_property_list_changed()

var initial_symbol : int:
	set(i):
		initial_symbol = i
		_initial_symbol2 = grammar.from_enum(i)

var initial_symbol_override : String:
	set(str):
		initial_symbol_override = str
		
			
		if grammar != null and grammar.has(str):
			_initial_symbol2 = str
			
		else:
			_initial_symbol2 = grammar.from_enum(initial_symbol)
			
var _initial_symbol2 : String:
	set(str):
		_initial_symbol2 = str
		initial_shape = grammar.get_shape(str)

var initial_shape : GrammarShape

# State
var shapes : Array[GrammarShape] = []
var terminals : Array[GrammarShape] = []

func _get_property_list():
	var properties = []
	
	var property_usage = PROPERTY_USAGE_NO_EDITOR
	var hint_string = ""
	
	if self.grammar != null:
		property_usage = PROPERTY_USAGE_DEFAULT
		hint_string = self.grammar.get_hints()
	
	properties = []
	properties.append({
		"name": "initial_symbol",
		"type": TYPE_INT,
		"usage": property_usage,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": hint_string
	})

	return properties

func _add_terminal(terminal_shape):
	self._terminals.push_back(terminal_shape)
	
func _clear_terminals():
	self._terminals = []
	
func start(_initial_symbol):
	self.initial_symbol = _initial_symbol
	
	self.shapes

# Fulfill a grammar
func next_generation():
	var old_shape_names = []
	var new_shape_names = []
	var new_shapes = []
	for shape in self.shapes:
		old_shape_names.append(shape.symbol.text)
		
		# Get the rule
		var grammar_rule = shape.symbol.select_rule()
		
		# No rules, keep the shape
		if grammar_rule == null:
			new_shapes.append(shape)
			
		else:
			var shapes = grammar_rule.fulfill(shape)
			
			new_shapes.append_array(shapes)
	
	# Split the new array between shapes and terminals
	self.shapes = []
	for shape in new_shapes:
		new_shape_names.append(shape.symbol.text)
		
		if shape.symbol.is_terminal():
			self._add_terminal(shape)
			
		else:
			self.shapes.push_back(shape)
