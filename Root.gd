extends Node3D

@onready var apply_rule = %ToolOpt/TestOpt/ApplyRule

const ROT_SPEED = 0.01
var mouse_down = false

const right_arrow = preload("res://textures/right-arrow.svg")
var right_arrow_img

# Preloads
const _simulacrumMat = preload("res://mats/simulacrum.tres")
const _contouredMat = preload("res://mats/contouredface.tres")
const _anchorMat = preload("res://mats/anchor.tres")
const _contouredShader = preload("res://shaders/contouredface.gdshader")
const _contouredAlphaShader = preload("res://shaders/contouredface_alpha.gdshader")
const _howerMat = preload("res://mats/hower.tres")
const _selectMat = preload("res://mats/select.tres")
const _howerselectMat = preload("res://mats/howerselect.tres")
const _marginMat = preload("res://mats/margin.tres")
const _cutMat = preload("res://mats/cut.tres")
const _env = preload("res://default_env.tres")

func _ready():
	%ToolOpt.mode_changed.connect(self._on_mode_change)
	self.right_arrow_img = right_arrow.get_image()
	self.presentation_rotation()

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
	return img
	
func save_image(img: Image):
	img.save_png("user://capture_" + Time.get_datetime_string_from_system().replace(":", "") + ".png")

func capture_rule():
	# Check if a rule is selected
	if not %RuleManager.has_active_rule():
		return
		
	var symbol = %RuleManager.get_symbol()
	var rule_index = %RuleManager.get_rule_index()
	
	# Capture the rule
	var rule_image = self.capture_screen()
	
	# Change to symbol
	%RuleManager.set_to_symbol(symbol)
	await self.get_tree( ).process_frame # Update the rotation of the symbol
	RenderingServer.force_draw()        # TODO: use ViewPort.force_draw when it is implemented
	
	# Capture the symbol
	var symbol_image = self.capture_screen()
	
	# Change back to rule
	%RuleManager.set_to_rule(symbol, rule_index)
	
	# Get the height and width
	# NOTE: rule_image and symbol_image should have the same size
	var h = rule_image.get_height()
	var w = rule_image.get_width()
	var sym_size = Vector2i(w, h)
	var rule_size = sym_size
	
	# Right arrow image dimensions
	const arrows_in_geom = 3
	var ah = roundi(float(h) / arrows_in_geom)
	var real_ah = self.right_arrow_img.get_height()
	var ratio = float(ah) / real_ah
	var real_aw = self.right_arrow_img.get_width()
	var aw = int(real_aw * ratio)
	var arrow_size = Vector2i(aw, ah)
	
	# Resize the right_arrow_img
	var rai = Image.new()
	rai.copy_from(right_arrow_img)
	rai.resize(aw, ah, Image.INTERPOLATE_LANCZOS)
	
	# Locations
	var sym_loc = Vector2i(0, 0)
	var arrow_loc = Vector2i(w, roundi(float(h - ah) / 2))
	var rule_loc = Vector2i(w + aw, 0)
	
	# Create the image for the result
	var res = Image.create(2*w + aw, h, false, Image.FORMAT_RGBA8)
	res.fill(Color(0, 0, 0, 0))
	
	# Insert the sub-images into the image
	var src_loc = Vector2i(0, 0)
	res.blit_rect(symbol_image, Rect2(src_loc, sym_size), sym_loc)
	res.blit_rect(rai, Rect2(src_loc, arrow_size), arrow_loc)
	res.blit_rect(rule_image, Rect2(src_loc, rule_size), rule_loc)
	
	return res

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
				var img = self.capture_screen()
				self.save_image(img)
				
			if event.keycode == KEY_O and event.ctrl_pressed:
				var img = await self.capture_rule()
				self.save_image(img)
					

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
