#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba8, set = 0, binding = 0) uniform restrict readonly  image2D start_image;
layout(rgba8, set = 1, binding = 0) uniform restrict writeonly image2D end_image;

// Our push constant
layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	vec2 reserved;
} params;

// The code we want to execute in each invocation
void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);

	// Prevent reading/writing out of bounds.
    if(uv.x + 4 >= size.x || uv.x - 4 < 0) {
        return;
    }
    if(uv.y + 4 >= size.y || uv.y - 4 < 0) {
        return;
    }

	vec3 color = imageLoad(start_image, uv).xyz;

	// vec3 color = imageLoad(start_image, uv).xyz * 0.16;
	// color += imageLoad(start_image, uv + ivec2(0,  1)).xyz * 0.15;
	// color += imageLoad(start_image, uv + ivec2(0, -1)).xyz * 0.15;
	// color += imageLoad(start_image, uv + ivec2(0,  2)).xyz * 0.12;
	// color += imageLoad(start_image, uv + ivec2(0, -2)).xyz * 0.12;
	// color += imageLoad(start_image, uv + ivec2(0,  3)).xyz * 0.09;
	// color += imageLoad(start_image, uv + ivec2(0, -3)).xyz * 0.09;
	// color += imageLoad(start_image, uv + ivec2(0,  4)).xyz * 0.05;
	// color += imageLoad(start_image, uv + ivec2(0, -4)).xyz * 0.05;

	// Write back to our color buffer.
	imageStore(end_image, uv, vec4(color, 1.0));
}
