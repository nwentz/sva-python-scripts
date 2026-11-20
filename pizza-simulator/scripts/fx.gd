class_name Fx
extends RefCounted
## Small helpers for particle effects.

## A puff of smoke that drifts upwards and fades out.
##
## A GPUParticles3D draws nothing unless it has a mesh to draw, so the quad
## and its soft, billboarded material are set up here.
static func make_smoke(amount: int = 16, lifetime: float = 2.4, rise: float = 0.25) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.1
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 20.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0, rise, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	pm.damping_min = 0.2
	pm.damping_max = 0.5

	# fade out towards the end of the particle's life
	var grad := Gradient.new()
	grad.set_color(0, Color(0.95, 0.9, 0.85, 0.55))
	grad.set_color(1, Color(0.7, 0.7, 0.7, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	pm.color_ramp = ramp
	p.process_material = pm

	# a soft round puff that always faces the camera
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true

	var tex := GradientTexture2D.new()
	var puff := Gradient.new()
	puff.set_color(0, Color(1, 1, 1, 1))
	puff.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = puff
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	mat.albedo_texture = tex

	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	quad.material = mat
	p.draw_pass_1 = quad

	p.emitting = false
	return p
