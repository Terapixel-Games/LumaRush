extends GdUnitTestSuite

func test_new_mood_change_cancels_previous_fade() -> void:
	var controller: BackgroundController = preload("res://src/visual/BackgroundController.tscn").instantiate()
	get_tree().root.add_child(controller)
	await get_tree().process_frame

	controller.set_mood(BackgroundMood.Mood.CALM, 6.0)
	await get_tree().process_frame
	controller.set_mood(BackgroundMood.Mood.HYPE, 0.05)
	await get_tree().create_timer(0.3).timeout

	var mat: ShaderMaterial = controller.bg_rect.material
	var color_a: Color = mat.get_shader_parameter("color_a")
	assert_that(color_a.r).is_less_equal(0.25)
	assert_that(color_a.g).is_less_equal(0.35)
	assert_that(color_a.b).is_greater_equal(0.45)
	controller.queue_free()

func test_match_pulse_tints_boost_particles_without_recoloring_ambient_particles() -> void:
	var controller: BackgroundController = preload("res://src/visual/BackgroundController.tscn").instantiate()
	get_tree().root.add_child(controller)
	await get_tree().process_frame

	var ambient_particles: GPUParticles2D = controller.get_node_or_null("Particles") as GPUParticles2D
	var boost_particles: GPUParticles2D = controller.get_node_or_null("BoostParticles") as GPUParticles2D
	var boost_streak_particles: GPUParticles2D = controller.get_node_or_null("BoostStreakParticles") as GPUParticles2D
	assert_that(ambient_particles).is_not_null()
	assert_that(boost_particles).is_not_null()
	assert_that(boost_streak_particles).is_not_null()
	var ambient_before: Color = ambient_particles.modulate
	var ambient_material: ParticleProcessMaterial = ambient_particles.process_material as ParticleProcessMaterial
	var ambient_material_color_before: Color = ambient_material.color
	var match_color := Color(1.0, 0.12, 0.02, 0.98)
	controller.pulse_starfield(1.4, match_color)
	await get_tree().process_frame

	var boost_color: Color = boost_particles.modulate
	var boost_material: ParticleProcessMaterial = boost_particles.process_material as ParticleProcessMaterial
	var boost_streak_material: ParticleProcessMaterial = boost_streak_particles.process_material as ParticleProcessMaterial
	var ambient_after: Color = ambient_particles.modulate
	assert_that(boost_particles.emitting).is_true()
	assert_that(boost_streak_particles.emitting).is_true()
	assert_that(boost_particles.amount).is_greater(ambient_particles.amount / 2)
	assert_that(boost_color.r).is_greater_equal(match_color.r - 0.001)
	assert_that(boost_color.g).is_greater(boost_color.b)
	assert_that(boost_material.color.r).is_greater_equal(match_color.r - 0.001)
	assert_that(boost_material.color.g).is_greater(boost_material.color.b)
	assert_that(boost_streak_material.color.r).is_greater_equal(match_color.r - 0.001)
	assert_that(boost_streak_material.color.g).is_greater(boost_streak_material.color.b)
	assert_that(ambient_after.r).is_equal(ambient_before.r)
	assert_that(ambient_after.g).is_equal(ambient_before.g)
	assert_that(ambient_after.b).is_equal(ambient_before.b)
	assert_that(ambient_material.color).is_equal(ambient_material_color_before)
	controller.queue_free()
