shader_type spatial;
render_mode unshaded;

uniform sampler2D GAUSSIAN_OUTPUT;

void vertex(){
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
    ALBEDO = texture(GAUSSIAN_OUTPUT, vec2(UV.x, -UV.y)).xyz;
}
