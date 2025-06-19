extends Camera3D

@onready var post_process_quad: MeshInstance3D = get_node("PostProcessQuad")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var mat: ShaderMaterial = post_process_quad.material_override
	if(mat):
		compositor.compositor_effects[0].output_texture = mat.get_shader_parameter("GAUSSIAN_OUTPUT")
		# print("compositor.compositor_effects[0].output_texture.texture_rd_rid = ", compositor.compositor_effects[0].output_texture.texture_rd_rid)
		print("after setting type of output_texture: ", typeof(compositor.compositor_effects[0].output_texture))
		print("shader_parameter: ", mat.get_shader_parameter("GAUSSIAN_OUTPUT"))
		print("typeof shader_parameter: ", typeof(mat.get_shader_parameter("GAUSSIAN_OUTPUT")))
	else:
		print("FAILED TO GET SHADER MATERIAL")
		print("after setting type of output_texture: ", typeof(compositor.compositor_effects[0].output_texture))
		print("shader_parameter: ", mat.get_shader_parameter("GAUSSIAN_OUTPUT"))
		print("typeof shader_parameter: ", typeof(mat.get_shader_parameter("GAUSSIAN_OUTPUT")))
