extends Node

var temp_path = "user://temp"
var user_path = null
var save_path = null
var upload_data = null
var proceed = false

signal finished_operation

enum UP_AXIS {
	X_UP, Y_UP, Z_UP,
	X_DOWN, Y_DOWN, Z_DOWN
}

static func save_file(path, contents: PackedByteArray):
	if OS.has_feature('web'):
		JavaScriptBridge.download_buffer(contents, path)
		
	else:
		var file = FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(contents)
		
func update_user_path():
	$SaveFile.popup()
	await self.finished_operation
	return self.proceed
	
func get_new_path():
	# Get the path
	var proc = await self.update_user_path()
	if not proc:
		return null
		
	return self.user_path

# https://godotengine.org/qa/129688/how-to-export-stl-from-gdscript
func save_meshes_as_stl(meshes):
	# Get the path
	var path = await self.get_new_path()
	if path == null:
		return false
	
	# Convert to STL format
	var mesh_name = "__mesh_name"
	var stl = ""
	stl += "solid " + mesh_name + "\n"
	
	const _up_axis = UP_AXIS.Z_UP
	var basis:Basis = Basis.IDENTITY
	match _up_axis:
		UP_AXIS.X_UP:
			basis = Quaternion(Vector3(0,0,1),PI*0.5)
		UP_AXIS.X_DOWN:
			basis = Quaternion(Vector3(0,0,1),PI*-0.5)
		UP_AXIS.Y_DOWN:
			basis = Quaternion(Vector3(1,0,0),PI)
		UP_AXIS.Z_UP:
			basis = Quaternion(Vector3(1,0,0),PI*0.5)
		UP_AXIS.Z_DOWN:
			basis = Quaternion(Vector3(1,0,0),PI*-0.5)
	
	for mesh in meshes:
		var faces = mesh.get_faces()
		var v3:Vector3
		for i in range(0,faces.size(),3):
			stl += "\tfacet\n"
			stl += "\t\touter loop\n"
			for j in range(0,3):
				v3 = faces[i+j]
				v3 = basis * v3
				stl += "\t\t\tvertex " + str(v3.x) + " " + str(v3.y) + " " + str(v3.z) + "\n"
			stl += "\t\tendloop\n"
			stl += "\tendfacet\n"
			
		stl += "endsolid " + mesh_name + "\n"
		
	save_file(path, stl.to_utf8_buffer())
	
	return true
	
func save_serialized_grammar():
	# Get the path
	var path = await self.get_new_path()
	if path == null:
		return false
		
	var sg = %Symbols.serialize_grammar()
		
	save_file(path, sg)
	
	return true
	
func save_grammar_resource():
	# Get the path
	var path = await self.get_new_path()
	if path == null:
		return false
		
	# Add file end
	
	if not path.ends_with(".grammar"):
		path += ".grammar"
		
	var gr = %Symbols.get_grammar_resource()
	var msg = ResourceSaver.save(gr, path)
	
	return true
	
func save(newpath=false):
	# AddSymbol save
	var add_symbol_save = %AddSymbol.save()
	
	# Symbols save
	var symbols_save = %Symbols.save()
	
	# Rules save
	var rules_save = %RuleManager.save()
	
	var saved = [add_symbol_save, symbols_save, rules_save]
	
	if OS.has_feature('web'):
		# Store to temporary file, then read it as binary, and write that binary to correct destination
		var file = FileAccess.open(temp_path, FileAccess.READ_WRITE)
		file.store_var(saved)
		file.seek(0)
		var _len = file.get_length()
		var packed = file.get_buffer(_len)
		
		JavaScriptBridge.download_buffer(packed, "save.bin")
		
		return true
		
	else:
		var need_a_newpath = save_path == null or newpath
		var proc = true
		if need_a_newpath:
			proc = await self.update_user_path()
			
		# Only do if self.proceed was not false
		if proc:
			self.save_path = self.user_path
			var file = FileAccess.open(self.save_path, FileAccess.WRITE)
			file.store_var(saved)
			
			return true
			
		return false

func l():
	var saved
	
	if OS.has_feature("web"):
		var window = JavaScriptBridge.get_interface("window")
		window.file_upload.click()
		
		await self.finished_operation

		var file = FileAccess.open(temp_path, FileAccess.READ_WRITE)
		file.store_buffer(self.upload_data)
		file.seek(0)
		saved = file.get_var()
		
	else:
		$LoadFile.popup()
		await self.finished_operation
		
		if self.proceed:
			var file = FileAccess.open(user_path, FileAccess.READ)
			saved = file.get_var()
		
		else:
			return false
		
	%SVC.visible = false
	
	# Load AddSymbol
	%AddSymbol.l(saved[0])
	
	# Load Symbols
	%Symbols.l(saved[1])
	
	const wait_frames = 3
	for i in wait_frames:
		await self.get_tree().process_frame
	
	# Load Rules
	%RuleManager.l(saved[2])
	
	%SVC.visible = true
	
	return true
	
func _on_file_selected(path):
	self.user_path = path
	
	self.proceed = true
	self.finished_operation.emit()
	
func _file_load_cb_fun(args):
	var jso = args[0]
	var _len = jso.byteLength
	var pba = PackedByteArray()
	
	for i in _len:
		pba.append(jso[i])
		
	self.upload_data = pba
	
	self.proceed = true
	self.finished_operation.emit()
	
var file_load_cb = JavaScriptBridge.create_callback(self._file_load_cb_fun)

func _on_cancle():
	self.proceed = false
	self.finished_operation.emit()
		
func _on_save(shifted):
	if await self.save(shifted):
		self._hide_project()
	
func _on_load():
	if await self.l():
		self._hide_project()
	
func _on_export():
	if await self.save_grammar_resource():
		self._hide_project()
	
func _toggle_project():
	$Project.visible = not $Project.visible
	
func _hide_project():
	$Project.visible = false
	
func _ready():
	if OS.has_feature("web"):
		var window = JavaScriptBridge.get_interface("window")
		window.setup_file_upload(file_load_cb)
		
	else:
		$SaveFile.file_selected.connect(self._on_file_selected)
		$LoadFile.file_selected.connect(self._on_file_selected)
		
		$SaveFile.canceled.connect(self._on_cancle)
		$LoadFile.canceled.connect(self._on_cancle)

	# Project window
	%RuleOpt/ProjectButton.pressed.connect(self._toggle_project)
	$Project.close_requested.connect(self._toggle_project)

	# Connect functionality buttons
	%SaveButton.pressed.connect(self._on_save.bind(false))
	%SaveAsButton.pressed.connect(self._on_save.bind(true))
	%LoadButton.pressed.connect(self._on_load)
	%ExportButton.pressed.connect(self._on_export)
		
func _input(event):
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_S and event.ctrl_pressed:
				self._on_save(event.shift_pressed)
				
			if event.keycode == KEY_L and event.ctrl_pressed:
				self._on_load()
				
			if event.keycode == KEY_B and event.ctrl_pressed:
				self._on_export()
				
				
