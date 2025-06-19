// steps to take:
// ✓✓✓ pixelate the image - downscale and then upscale it (perhaps a mipmap can be used since they are powers of 2)

// ✓✓✓ limit the intensity of color so it can be mapped to ascii characters

// ✓✓✓ render all characters instead of pixels

// use the difference of gaussians to detect edges

// use the sobel filters to get the vector field

// replace the coresponding pixels with edgelines


shader_type canvas_item;

// If you intend to read from mipmaps with `textureLod()` LOD values greater than `0.0`,
// use `filter_nearest_mipmap` instead. This shader doesn't require it.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest_mipmap;
uniform sampler2DArray custom_chars;

// uniform vec3 color_dark   = vec3(0.1, 0.05, 0.05);
// uniform vec3 color_bright = vec3(0.7, 0.8, 0.9);
uniform vec3 color_dark   : source_color = vec3(0.0, 0.0, 0.0);
uniform vec3 color_bright : source_color = vec3(1.0, 1.0, 1.0);

void fragment() {
    // use mipmaps to display downscaled image (should work in a 3D scene, in case it doesn't, check the glsl to godot manual page)
    vec4 pixelated = textureLod(screen_texture, SCREEN_UV, 3.0);

    // can use the monochrome as pixel color for a one bit style
    // float pixel_intensity = floor(length(pixelated.xyz)*10.0)/10.0;
    // vec3 custom_color = mix(color_dark, color_bright, pixel_intensity);
    // vec4 monochrome = vec4(custom_color, pixelated.a);

    int char_idx = int(floor(length(pixelated.xyz)*10.0));
    // int char_idx = int(floor(dot(pixelated.xyz, vec3(0.333))*10.0)); // consider this optimization trick
    char_idx = clamp(char_idx, 0, 9);

    vec2 char_uv = mod(FRAGCOORD.xy, vec2(8.0, 8.0))/8.0;
    vec4 char_pixel = texture(custom_chars, vec3(char_uv, float(char_idx))); // doesn't work :<

    COLOR = char_pixel * pixelated;
}
