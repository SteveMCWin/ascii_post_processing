@tool
class_name PostProcessGaussian
extends CompositorEffect

var rd: RenderingDevice
var gausian_compute_h: RID
var gausian_compute_v: RID
var gausian_pipeline_h: RID
var gausian_pipeline_v: RID

var texture_rds: Array[RID] = [RID(), RID()]
var texture_sets: Array[RID] = [RID(), RID()]

var output_texture: Texture2DRD

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_initialize_compute)


# System notifications, we want to react on the notification that
# alerts us we are about to be destroyed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		rd.free_rid(texture_rds[0])
		rd.free_rid(texture_rds[1])

		if gausian_compute_h.is_valid():
			rd.free_rid(gausian_compute_h)

		if gausian_compute_v.is_valid():
			rd.free_rid(gausian_compute_v)


# Compile our grayscale_compute at initialization.
func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		return

	# Gaussian stuff
	var gausian_file_h := load("res://scripts/gausian_compute_h.glsl")
	var gausian_file_v := load("res://scripts/gausian_compute_v.glsl")
	var gausian_spirv_h : RDShaderSPIRV = gausian_file_h.get_spirv()
	var gausian_spirv_v : RDShaderSPIRV = gausian_file_v.get_spirv()

	gausian_compute_h = rd.shader_create_from_spirv(gausian_spirv_h)
	gausian_compute_v = rd.shader_create_from_spirv(gausian_spirv_v)

	if gausian_compute_h.is_valid():
		gausian_pipeline_h = rd.compute_pipeline_create(gausian_compute_h)
	if gausian_compute_v.is_valid():
		gausian_pipeline_v = rd.compute_pipeline_create(gausian_compute_v)
	
	var tf: RDTextureFormat = RDTextureFormat.new()
	tf.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.width = 1920  # WARNING: hard coded
	tf.height = 1080 # WARNING: hard coded
	tf.depth = 1
	tf.array_layers = 1
	tf.mipmaps = 1
	tf.usage_bits = (
			RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
			RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT |
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
			RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT |
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	)

	for i in 2:
		# Create our texture.
		texture_rds[i] = rd.texture_create(tf, RDTextureView.new(), [])

		# Make sure our textures are cleared.
		rd.texture_clear(texture_rds[i], Color(0, 0, 0, 0), 0, 1, 0, 1)

	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(texture_rds[0])
	texture_sets[0] = rd.uniform_set_create([uniform], gausian_compute_h, 0)

	uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(texture_rds[1])
	texture_sets[1] = rd.uniform_set_create([uniform], gausian_compute_v, 0)



func gausian_blur(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if rd and p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_TRANSPARENT and gausian_pipeline_h.is_valid() and gausian_pipeline_v.is_valid():
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
				var color_buff: RID = render_scene_buffers.get_color_layer(view)

				# Create a uniform set, this will be cached, the cache will be cleared if our viewports configuration is changed.
				var uniform := RDUniform.new()
				uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
				uniform.binding = 0
				uniform.add_id(color_buff)
				var color_buff_set := UniformSetCacheRD.get_cache(gausian_compute_h, 0, [uniform])

				# Run our compute grayscale_compute.
				var compute_list := rd.compute_list_begin()

				rd.compute_list_bind_compute_pipeline(compute_list, gausian_pipeline_h)
				rd.compute_list_bind_uniform_set(compute_list, color_buff_set, 0)
				rd.compute_list_bind_uniform_set(compute_list, texture_sets[0], 1)
				rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)

				rd.compute_list_bind_compute_pipeline(compute_list, gausian_pipeline_v)
				rd.compute_list_bind_uniform_set(compute_list, texture_sets[0], 0)
				rd.compute_list_bind_uniform_set(compute_list, texture_sets[1], 1)
				rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)

				rd.compute_list_end()

				if output_texture:
					output_texture.texture_rd_rid = texture_rds[1]
					# print("output_texture.texture_rd_rid: ", output_texture.texture_rd_rid)
					# print("texture_rds[1]: ", texture_rds[1])


# Called by the rendering thread every frame.
func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	gausian_blur(p_effect_callback_type, p_render_data)
