@tool
class_name PostProcessGrayScale
extends CompositorEffect

var rd: RenderingDevice
var grayscale_compute: RID
var gausian_compute_h: RID
var gausian_compute_v: RID
var pipeline: RID
var gausian_pipeline_h: RID
var gausian_pipeline_v: RID


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_initialize_compute)


# System notifications, we want to react on the notification that
# alerts us we are about to be destroyed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if grayscale_compute.is_valid():
			# Freeing our grayscale_compute will also free any dependents such as the pipeline!
			rd.free_rid(grayscale_compute)
			rd.free_rid(gausian_compute_h)
			rd.free_rid(gausian_compute_v)


#region Code in this region runs on the rendering thread.
# Compile our grayscale_compute at initialization.
func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		return

	# Compile our grayscale_compute.
	var shader_file := load("res://scripts/grayscale_post.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()

	grayscale_compute = rd.shader_create_from_spirv(shader_spirv)
	if grayscale_compute.is_valid():
		pipeline = rd.compute_pipeline_create(grayscale_compute)
	
	var gausian_file_h := load("res://scripts/gausian_compute_h.glsl")
	var gausian_file_v := load("res://scripts/gausian_compute_v.glsl")
	var gausian_spirv_h : RDShaderSPIRV = gausian_file_h.get_spirv()
	var gausian_spirv_v : RDShaderSPIRV = gausian_file_v.get_spirv()

	gausian_compute_h = rd.shader_create_from_spirv(gausian_spirv_h)
	gausian_compute_v = rd.shader_create_from_spirv(gausian_spirv_v)

	if gausian_compute_h.is_valid():
		gausian_pipeline_h = rd.compute_pipeline_create(gausian_pipeline_h)
	if gausian_compute_v.is_valid():
		gausian_pipeline_v = rd.compute_pipeline_create(gausian_pipeline_v)

func grayscale_effect(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if rd and p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_TRANSPARENT and pipeline.is_valid():
		# Get our render scene buffers object, this gives us access to our render buffers.
		# Note that implementation differs per renderer hence the need for the cast.
		var render_scene_buffers := p_render_data.get_render_scene_buffers()
		if render_scene_buffers:
			# Get our render size, this is the 3D render resolution!
			var size: Vector2i = render_scene_buffers.get_internal_size()
			if size.x == 0 and size.y == 0:
				return

			# We can use a compute grayscale_compute here.
			@warning_ignore("integer_division")
			var x_groups := (size.x - 1) / 8 + 1
			@warning_ignore("integer_division")
			var y_groups := (size.y - 1) / 8 + 1
			var z_groups := 1

			# Create push constant.
			# Must be aligned to 16 bytes and be in the same order as defined in the grayscale_compute.
			var push_constant := PackedFloat32Array([
				size.x,
				size.y,
				0.0,
				0.0,
			])

			# Loop through views just in case we're doing stereo rendering. No extra cost if this is mono.
			var view_count: int = render_scene_buffers.get_view_count()
			for view in view_count:
				# Get the RID for our color image, we will be reading from and writing to it.
				var input_image: RID = render_scene_buffers.get_color_layer(view)

				# Create a uniform set, this will be cached, the cache will be cleared if our viewports configuration is changed.
				var uniform := RDUniform.new()
				uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
				uniform.binding = 0
				uniform.add_id(input_image)
				var uniform_set := UniformSetCacheRD.get_cache(grayscale_compute, 0, [uniform])

				# Run our compute grayscale_compute.
				var compute_list := rd.compute_list_begin()
				rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
				rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
				rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
				rd.compute_list_end()


func gausian_blur(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if rd and p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_TRANSPARENT and pipeline.is_valid():
		# Get our render scene buffers object, this gives us access to our render buffers.
		# Note that implementation differs per renderer hence the need for the cast.
		var render_scene_buffers := p_render_data.get_render_scene_buffers()
		if render_scene_buffers:
			# Get our render size, this is the 3D render resolution!
			var size: Vector2i = render_scene_buffers.get_internal_size()
			if size.x == 0 and size.y == 0:
				return

			# We can use a compute grayscale_compute here.
			@warning_ignore("integer_division")
			var x_groups := (size.x - 1) / 8 + 1
			@warning_ignore("integer_division")
			var y_groups := (size.y - 1) / 8 + 1
			var z_groups := 1

			# Create push constant.
			# Must be aligned to 16 bytes and be in the same order as defined in the grayscale_compute.
			var push_constant := PackedFloat32Array([
				size.x,
				size.y,
				0.0,
				0.0,
			])

			# Loop through views just in case we're doing stereo rendering. No extra cost if this is mono.
			var view_count: int = render_scene_buffers.get_view_count()
			for view in view_count:
				# Get the RID for our color image, we will be reading from and writing to it.
				var input_image: RID = render_scene_buffers.get_color_layer(view)

				# Create a uniform set, this will be cached, the cache will be cleared if our viewports configuration is changed.
				var uniform := RDUniform.new()
				uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
				uniform.binding = 0
				uniform.add_id(input_image)
				var uniform_set := UniformSetCacheRD.get_cache(grayscale_compute, 0, [uniform])

				# Run our compute grayscale_compute.
				var compute_list := rd.compute_list_begin()
				rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
				rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
				rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
				rd.compute_list_end()




# Called by the rendering thread every frame.
func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	grayscale_effect(p_effect_callback_type, p_render_data)
#endregion
