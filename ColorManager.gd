extends Node

const contouredMat = preload("res://mats/contouredface.tres")

var rng = RandomNumberGenerator.new()

func color_near(proto: Color, variance=0.1):
	var r = self.rng.randf_range(max(proto.r - variance, 0), min(proto.r + variance, 1))
	
	var g_var = proto.g * variance
	var g = self.rng.randf_range(max(proto.g - variance, 0), min(proto.g + variance, 1))
	
	var b_var = proto.b * variance
	var b = self.rng.randf_range(max(proto.b - variance, 0), min(proto.b + variance, 1))
	
	return Color(r, g, b, proto.a)

# 82, 255, 184 -- 0.32, 1, 0.72
func color_gen():
	#return Color(self.rng.randf_range(0.5, 0.9), self.rng.randf_range(0.5, 0.9), self.rng.randf_range(0.5, 0.9), 1.0)
	return self.color_near(Color(0.32, 1, 0.72, 1), 0.22)
	
func get_contoured_mat():
	var new_color = self.color_gen()
	var newMat = self.contouredMat.duplicate()
	newMat.set_shader_parameter("albedo_color", new_color)
	return newMat
