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
	var boost_long_streak_particles: GPUParticles2D = controller.get_node_or_null("BoostLongStreakParticles") as GPUParticles2D
	assert_that(ambient_particles).is_not_null()
	assert_that(boost_particles).is_not_null()
	assert_that(boost_streak_particles).is_not_null()
	assert_that(boost_long_streak_particles).is_not_null()
	var ambient_before: Color = ambient_particles.modulate
	var ambient_material: ParticleProcessMaterial = ambient_particles.process_material as ParticleProcessMaterial
	var ambient_material_color_before: Color = ambient_material.color
	var match_color := Color(1.0, 0.12, 0.02, 0.98)
	controller.pulse_starfield(1.4, match_color)
	await get_tree().process_frame

	var boost_color: Color = boost_particles.modulate
	var boost_material: ParticleProcessMaterial = boost_particles.process_material as ParticleProcessMaterial
	var boost_streak_material: ParticleProcessMaterial = boost_streak_particles.process_material as ParticleProcessMaterial
	var boost_long_streak_material: ParticleProcessMaterial = boost_long_streak_particles.process_material as ParticleProcessMaterial
	var ambient_after: Color = ambient_particles.modulate
	assert_that(boost_particles.emitting).is_true()
	assert_that(boost_streak_particles.emitting).is_true()
	assert_that(boost_long_streak_particles.emitting).is_true()
	assert_that(boost_particles.amount).is_greater(ambient_particles.amount)
	assert_that(boost_streak_particles.amount).is_greater(streak_particles_amount_floor(controller))
	assert_that(boost_long_streak_particles.amount).is_greater(80)
	var viewport_radius: float = controller.get_viewport_rect().size.length() * 0.5
	var streak_travel_budget: float = (
		boost_streak_material.initial_velocity_max * boost_streak_particles.lifetime
		+ (0.5 * boost_streak_material.linear_accel_max * boost_streak_particles.lifetime * boost_streak_particles.lifetime)
	) * boost_streak_particles.speed_scale
	var long_streak_travel_budget: float = (
		boost_long_streak_material.initial_velocity_max * boost_long_streak_particles.lifetime
		+ (0.5 * boost_long_streak_material.linear_accel_max * boost_long_streak_particles.lifetime * boost_long_streak_particles.lifetime)
	) * boost_long_streak_particles.speed_scale
	assert_that(streak_travel_budget).is_greater_equal(viewport_radius)
	assert_that(long_streak_travel_budget).is_greater_equal(viewport_radius * 2.0)
	assert_that(boost_material.emission_shape).is_equal(ambient_material.emission_shape)
	assert_that(boost_streak_material.emission_shape).is_equal(ambient_material.emission_shape)
	assert_that(boost_long_streak_material.emission_shape).is_equal(ambient_material.emission_shape)
	assert_that(boost_color.r).is_greater_equal(match_color.r - 0.001)
	assert_that(boost_color.g).is_greater(boost_color.b)
	assert_that(boost_material.color.r).is_greater_equal(match_color.r - 0.001)
	assert_that(boost_material.color.g).is_greater(boost_material.color.b)
	assert_that(boost_streak_material.color.r).is_greater_equal(match_color.r - 0.001)
	assert_that(boost_streak_material.color.g).is_greater(boost_streak_material.color.b)
	assert_that(ambient_after.r).is_equal_approx(ambient_before.r, 0.01)
	assert_that(ambient_after.g).is_equal_approx(ambient_before.g, 0.01)
	assert_that(ambient_after.b).is_equal_approx(ambient_before.b, 0.01)
	assert_that(ambient_material.color).is_equal(ambient_material_color_before)
	controller.queue_free()

func test_match_burst_survives_pulse_taper_so_particles_can_exit_view() -> void:
	var controller: BackgroundController = preload("res://src/visual/BackgroundController.tscn").instantiate()
	get_tree().root.add_child(controller)
	await get_tree().process_frame

	controller.pulse_starfield(1.4, Color(0.0, 1.0, 0.18, 1.0))
	var boost_particles: GPUParticles2D = controller.get_node_or_null("BoostParticles") as GPUParticles2D
	var boost_streak_particles: GPUParticles2D = controller.get_node_or_null("BoostStreakParticles") as GPUParticles2D
	var boost_long_streak_particles: GPUParticles2D = controller.get_node_or_null("BoostLongStreakParticles") as GPUParticles2D
	assert_that(boost_particles).is_not_null()
	assert_that(boost_streak_particles).is_not_null()
	assert_that(boost_long_streak_particles).is_not_null()
	var burst_particle_amount: int = boost_particles.amount
	var burst_streak_amount: int = boost_streak_particles.amount
	var burst_long_streak_amount: int = boost_long_streak_particles.amount
	await get_tree().create_timer(FeatureFlags.starfield_match_pulse_seconds() * 2.4).timeout

	assert_that(boost_particles.emitting).is_true()
	assert_that(boost_streak_particles.emitting).is_true()
	assert_that(boost_long_streak_particles.emitting).is_true()
	assert_that(boost_particles.amount).is_equal(burst_particle_amount)
	assert_that(boost_streak_particles.amount).is_equal(burst_streak_amount)
	assert_that(boost_long_streak_particles.amount).is_equal(burst_long_streak_amount)
	assert_that(boost_particles.amount).is_greater(1000)
	assert_that(boost_streak_particles.amount).is_greater(300)
	assert_that(boost_long_streak_particles.amount).is_greater(100)
	assert_that(boost_streak_particles.lifetime).is_greater(FeatureFlags.starfield_match_pulse_seconds() * 6.0)
	assert_that(boost_long_streak_particles.lifetime).is_greater(FeatureFlags.starfield_match_pulse_seconds() * 6.0)
	controller.queue_free()

func test_immediate_duplicate_match_pulses_coalesce_into_single_background_burst() -> void:
	var controller: BackgroundController = preload("res://src/visual/BackgroundController.tscn").instantiate()
	get_tree().root.add_child(controller)
	await get_tree().process_frame

	controller.pulse_starfield(1.2, Color(1.0, 0.1, 0.02, 1.0))
	var first_serial: int = controller._boost_burst_serial
	var boost_particles: GPUParticles2D = controller.get_node_or_null("BoostParticles") as GPUParticles2D
	var boost_streak_particles: GPUParticles2D = controller.get_node_or_null("BoostStreakParticles") as GPUParticles2D
	assert_that(boost_particles).is_not_null()
	assert_that(boost_streak_particles).is_not_null()
	var first_particle_amount: int = boost_particles.amount
	var first_streak_amount: int = boost_streak_particles.amount

	controller.pulse_starfield(2.0, Color(0.0, 1.0, 0.18, 1.0))
	await get_tree().process_frame

	assert_that(controller._boost_burst_serial).is_equal(first_serial)
	assert_that(boost_particles.emitting).is_true()
	assert_that(boost_streak_particles.emitting).is_true()
	assert_that(boost_particles.amount).is_greater_equal(first_particle_amount)
	assert_that(boost_streak_particles.amount).is_greater_equal(first_streak_amount)
	controller.queue_free()

func test_later_match_pulse_uses_another_burst_slot_without_restarting_visible_burst() -> void:
	var controller: BackgroundController = preload("res://src/visual/BackgroundController.tscn").instantiate()
	get_tree().root.add_child(controller)
	await get_tree().process_frame

	controller.pulse_starfield(1.2, Color(1.0, 0.1, 0.02, 1.0))
	var first_serial: int = controller._boost_burst_serial
	var first_particles: GPUParticles2D = controller.get_node_or_null("BoostParticles") as GPUParticles2D
	var second_particles: GPUParticles2D = controller.get_node_or_null("BoostParticlesSlot2") as GPUParticles2D
	assert_that(first_particles).is_not_null()
	assert_that(second_particles).is_not_null()
	await get_tree().create_timer(float(BackgroundController.BOOST_BURST_DEDUPE_MSEC) / 1000.0 + 0.04).timeout
	first_particles.emitting = false

	controller.pulse_starfield(2.0, Color(0.0, 1.0, 0.18, 1.0))
	await get_tree().process_frame

	assert_that(controller._boost_burst_serial).is_equal(first_serial + 1)
	assert_that(first_particles.emitting).is_false()
	assert_that(second_particles.emitting).is_true()
	controller.queue_free()

func test_match_burst_pool_expands_instead_of_dropping_color_burst_when_slots_are_busy() -> void:
	var controller: BackgroundController = preload("res://src/visual/BackgroundController.tscn").instantiate()
	get_tree().root.add_child(controller)
	await get_tree().process_frame

	var now_msec: int = Time.get_ticks_msec()
	for slot in controller._boost_burst_slots:
		slot["lockout_until_msec"] = now_msec + 10000
	var initial_slot_count: int = controller._boost_burst_slots.size()
	var initial_serial: int = controller._boost_burst_serial

	controller.pulse_starfield(1.8, Color(0.0, 0.9, 1.0, 1.0))
	await get_tree().process_frame

	assert_that(controller._boost_burst_slots.size()).is_equal(initial_slot_count + 1)
	assert_that(controller._boost_burst_serial).is_equal(initial_serial + 1)
	var overflow_particles: GPUParticles2D = controller.get_node_or_null("BoostParticlesSlot%d" % (initial_slot_count + 1)) as GPUParticles2D
	assert_that(overflow_particles).is_not_null()
	assert_that(overflow_particles.emitting).is_true()
	controller.queue_free()

func streak_particles_amount_floor(controller: BackgroundController) -> int:
	var streak_particles: GPUParticles2D = controller.get_node_or_null("StreakParticles") as GPUParticles2D
	if streak_particles == null:
		return 1
	return streak_particles.amount
