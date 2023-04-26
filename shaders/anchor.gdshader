shader_type spatial;
render_mode unshaded;

uniform sampler2D anchor_texture : filter_linear;
uniform vec4 color;
uniform vec4 outline;

void fragment() {
	vec4 frag = texture(anchor_texture, UV);
	vec4 main_frag = frag.r * color;
	vec4 outline_frag = frag.g * outline;
	vec4 combined = main_frag + outline_frag;
	
	ALBEDO = combined.rgb;
	ALPHA = frag.a * combined.a;
}
