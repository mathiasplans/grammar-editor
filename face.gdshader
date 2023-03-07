shader_type spatial;

void fragment() {
	if (UV2.x > 0.9)
		ALBEDO = vec3(0.0, 1.0, 0.0);
		
	else
		ALBEDO = vec3(1.0, 0.0, 0.0);
		
	ALPHA = 1.0;
}