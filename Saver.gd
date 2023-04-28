extends HSplitContainer

var save_path = "user://save"

func save():
	# AddSymbol save
	var add_symbol_save = %AddSymbol.save()
	
	# Symbols save
	var symbols_save = %Symbols.save()
	
	# Rules save
	var rules_save = %RuleManager.save()
	
	var saved = [add_symbol_save, symbols_save, rules_save]
	
	# Store to the file
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_var(saved)
	
func l():
	%SVC.visible = false
	# Load from the file
	var file = FileAccess.open(save_path, FileAccess.READ)
	var saved = file.get_var()
	
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
	
func _input(event):
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_S and event.ctrl_pressed:
				self.save()
				
			if event.keycode == KEY_L and event.ctrl_pressed:
				self.l()
