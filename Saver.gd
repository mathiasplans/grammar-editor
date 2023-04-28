extends HSplitContainer

var temp_path = "user://tempsave"
var user_path = null
var upload_data = null
var proceed = false

signal finished_operation

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
		var len = file.get_length()
		var packed = file.get_buffer(len)
		
		JavaScriptBridge.download_buffer(packed, "save.bin")
		
	else:
		var need_a_newpath = user_path == null or newpath
		var proc = true
		if need_a_newpath:
			%Pops/SaveFile.popup()
			await self.finished_operation
			proc = self.proceed
			
		# Only do if self.proceed was not false
		if proc:
			var file = FileAccess.open(user_path, FileAccess.WRITE)
			file.store_var(saved)

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
		%Pops/LoadFile.popup()
		await self.finished_operation
		
		if self.proceed:
			var file = FileAccess.open(user_path, FileAccess.READ)
			saved = file.get_var()
		
		else:
			return
		
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
	
func _on_file_selected(path):
	self.user_path = path
	
	self.proceed = true
	self.finished_operation.emit()
	
func _file_load_cb_fun(args):
	var jso = args[0]
	var len = jso.byteLength
	var pba = PackedByteArray()
	
	for i in len:
		pba.append(jso[i])
		
	self.upload_data = pba
	
	self.proceed = true
	self.finished_operation.emit()
	
var file_load_cb = JavaScriptBridge.create_callback(self._file_load_cb_fun)

func _on_cancle():
	self.proceed = false
	self.finished_operation.emit()

func _ready():
	if OS.has_feature("web"):
		var window = JavaScriptBridge.get_interface("window")
		window.setup_file_upload(file_load_cb)
		
	else:
		%Pops/SaveFile.file_selected.connect(self._on_file_selected)
		%Pops/LoadFile.file_selected.connect(self._on_file_selected)
		
		%Pops/SaveFile.canceled.connect(self._on_cancle)
		%Pops/LoadFile.canceled.connect(self._on_cancle)
		
func _input(event):
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_S and event.ctrl_pressed:
				self.save(event.shift_pressed)
				
			if event.keycode == KEY_L and event.ctrl_pressed:
				self.l()
