extends Node3D

@onready var apply_rule = %ToolOpt/TestOpt/ApplyRule

const ROT_SPEED = 0.01
var mouse_down = false

func _ready():
	%ToolOpt.mode_changed.connect(self._on_mode_change)

# https://godotengine.org/qa/92394/can-i-split-texture-to-multiple-parts-or-crop-it
func _get_cropped_texture(texture : Texture, region : Rect2) -> AtlasTexture:
	var atlas_texture := AtlasTexture.new()
	atlas_texture.set_atlas(texture)
	atlas_texture.set_region(region)
	return atlas_texture
	
func presentation_rotation():
	self.look_at(Vector3(1, 0, -1))
	self.global_rotate(Vector3(1, 0, 0), PI/4)
	
func capture_screen():
	var verts
	
	# Get the vertices from Tester
	if $Tester.active():
		verts = $Tester.get_corners()
	
	# Get the vertices from Editor
	else:
		verts = $Editor.get_corners()
		
	# Transform the vertices into screenspace
	var screen_points = []
	for vert in verts:
		screen_points.append(%Cam.unproject_position(vert))
		
	# Get the maximum, minimum of both axis
	var max_coord = Vector2(0, 0)
	var min_coord = Vector2(10000000, 10000000)
	
	for sp in screen_points:
		max_coord.x = max(max_coord.x, sp.x)
		max_coord.y = max(max_coord.y, sp.y)
		min_coord.x = min(min_coord.x, sp.x)
		min_coord.y = min(min_coord.y, sp.y)
		
	const margin = 20
	const margin_vec = Vector2(margin, margin)
	var loc = min_coord - margin_vec
	var size = max_coord - min_coord + 2*margin_vec
	
	var region = Rect2(loc, size)
	
	# Get the texture of the viewport
	var vp_tex = self.get_viewport().get_texture()
	
	# Cropped texture
	var vp_tex_cropped = _get_cropped_texture(vp_tex, region)
	
	# Save the texture to a file
	var img = vp_tex_cropped.get_image()
	img.save_png("user://capture_" + Time.get_datetime_string_from_system().replace(":", "") + ".png")

func _input(event):
	# Camera rotation
	if event is InputEventMouseButton:
		self.mouse_down = event.is_pressed()
		
	if event is InputEventMouseMotion:
		if self.mouse_down:
			self.rotate(Vector3.UP, event.relative.x * ROT_SPEED)
			self.rotate(Vector3.RIGHT, event.relative.y * ROT_SPEED)
			
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_X:
				self.presentation_rotation()
				
			if event.keycode == KEY_P and event.ctrl_pressed:
				self.capture_screen()
					

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
