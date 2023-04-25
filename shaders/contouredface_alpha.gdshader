shader_type spatial;

uniform vec4 albedo_color;
uniform float transparency;

void fragment() {
	ALBEDO = (albedo_color * COLOR).xyz;
	ALPHA = transparency;
}