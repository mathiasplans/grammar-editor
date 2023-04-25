shader_type spatial;

uniform vec4 albedo_color;

void fragment() {
	ALBEDO = (albedo_color * COLOR).xyz;
}