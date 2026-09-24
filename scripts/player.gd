class_name Player
extends CharacterBody2D

@export var stamina_bar: ColorRect
@export var stamina_color: Color = Color.WHITE
@export var stamina_no_dash_color: Color = Color.CYAN

var run_speed := 360.0
var ground_accel := 2800.0
var air_accel := 2000.0
var ground_friction := 2400.0
var air_friction := 500.0
var jump_velocity := -620.0
var gravity := 1800.0
var max_fall_speed := 900.0
var coyote_time := 0.1
var jump_buffer_time := 0.15
var jump_cut_multiplier := 0.5
var dash_speed := 950.0
var dash_time := 0.18
var dash_cooldown := 0.08
var dash_buffer_time := 0.15
var max_air_dashes := 1
var climb_up_speed := 100.0
var climb_down_speed := 180.0
var climb_accel := 1600.0
var wall_stick_speed := 120.0
var wall_slide_speed := 120.0
var wall_slide_accel := 3500.0
var wall_jump_x_force := 330.0
var wall_jump_y_force := 600.0
var wall_jump_lockout := 0.1
var climb_contact_grace := 0.08
var crouch_speed := 180.0
var slide_speed := 900.0
var slide_friction := 800.0
var slide_min_speed := 200.0
var max_stamina := 100.0
var stamina_regen_rate := 60.0
var stamina_drain_rate := 12.0
var stamina_climb_up_rate := 25.0
var stamina_climb_down_rate := 6.0
var spring_gravity_multiplier := 2.2
var spring_gravity_duration := 0.35
var grab_slide_speed := 0.0
var swim_force := 1800.0

var water_swim_speed := 140.0
var water_swim_accel := 600.0
var water_swim_drag := 350.0
var water_dash_speed := 250.0
var water_dash_drag := 300.0
var water_gravity := 200.0

var input_dir := Vector2.ZERO
var facing := 1
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var dash_buffer_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_recharge_timer := 0.0
var dash_timer := 0.0
var dash_elapsed := 0.0
var dash_dir := Vector2.RIGHT
var dashes_remaining := 1
var is_climbing := false
var climb_wall_side := 0
var touch_wall_side := 0
var climb_lockout_timer := 0.0
var climb_lost_timer := 0.0
var is_crouching := false
var is_sliding := false
var slide_timer := 0.0
var climbing_platform: Node2D = null
var current_stamina := 100.0
var original_stamina_bar_width := 0.0
var spring_gravity_timer := 0.0
var is_in_water := false

var is_trapped := false
var trap_center := Vector2.ZERO
var trap_radius := 0.0

var original_collision_extents := Vector2.ZERO
var crouch_collision_extents := Vector2.ZERO
var original_color_rect_size := Vector2.ZERO
var original_color_rect_position := Vector2.ZERO
var crouch_color_rect_size := Vector2.ZERO
var crouch_color_rect_position := Vector2.ZERO

func _ready() -> void:
	dashes_remaining = max_air_dashes
	current_stamina = max_stamina
	add_to_group("player")
	floor_max_angle = deg_to_rad(70.0)
	
	if stamina_bar:
		original_stamina_bar_width = stamina_bar.size.x
		stamina_bar.color = stamina_color
	
	var collision_shape := get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape is RectangleShape2D:
		original_collision_extents = collision_shape.shape.extents
		crouch_collision_extents = original_collision_extents * 0.6
	
	var color_rect := get_node_or_null("ColorRect")
	if color_rect:
		original_color_rect_size = color_rect.size
		original_color_rect_position = color_rect.position
		crouch_color_rect_size = original_color_rect_size * Vector2(1.0, 0.6)
		crouch_color_rect_position = original_color_rect_position + Vector2(0.0, original_color_rect_size.y * 0.4)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	elif event.is_action_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier
	elif event.is_action_pressed("dash"):
		dash_buffer_timer = dash_buffer_time

func _physics_process(delta: float) -> void:
	input_dir = get_input_direction()
	if absf(input_dir.x) > 0.1:
		facing = 1 if input_dir.x > 0.0 else -1

	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	dash_buffer_timer = maxf(dash_buffer_timer - delta, 0.0)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
	dash_recharge_timer = maxf(dash_recharge_timer - delta, 0.0)
	climb_lockout_timer = maxf(climb_lockout_timer - delta, 0.0)
	spring_gravity_timer = maxf(spring_gravity_timer - delta, 0.0)

	if is_trapped:
		run_trapped(delta)
		move_and_slide()
		return

	if is_in_water:
		run_water(delta)
		move_and_slide()
		update_stamina(delta)
		update_stamina_bar()
		return

	update_crouch_state()

	if is_climbing and current_stamina <= 0.0:
		reset_climb_state()

	update_wall_contact()
	update_climb_state(delta)

	if is_on_floor():
		coyote_timer = coyote_time
		dashes_remaining = max_air_dashes
	elif dash_timer <= 0.0 and not is_climbing:
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	if dash_buffer_timer > 0.0 and dash_recharge_timer <= 0.0 and dashes_remaining > 0:
		start_dash()

	var can_wall_jump := touch_wall_side != 0 and not is_on_floor()
	var can_jump := jump_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0 or is_climbing or can_wall_jump)
	var can_interrupt_dash := dash_timer <= 0.0 or dash_elapsed > 0.06
	if can_jump and can_interrupt_dash and not is_sliding:
		do_jump()

	if is_sliding:
		run_slide(delta)
	elif dash_timer > 0.0:
		run_dash(delta)
	elif is_climbing:
		run_climb(delta)
	else:
		run_normal(delta)

	if climbing_platform:
		velocity += climbing_platform.get_platform_velocity()

	move_and_slide()

	if is_on_floor():
		dashes_remaining = max_air_dashes
		coyote_timer = coyote_time
		spring_gravity_timer = 0.0

	update_stamina(delta)
	update_stamina_bar()

func run_trapped(delta: float) -> void:
	if dash_buffer_timer > 0.0 and dashes_remaining > 0:
		exit_trap()
		dashes_remaining += 1
		start_dash()
		dash_recharge_timer = 0.0
		dash_cooldown_timer = 0.0
		return

	if input_dir != Vector2.ZERO:
		velocity += input_dir.normalized() * swim_force * delta

func enter_trap(center: Vector2, radius: float) -> void:
	is_trapped = true
	trap_center = center
	trap_radius = radius
	velocity = Vector2.ZERO
	dash_recharge_timer = 0.0
	dash_cooldown_timer = 0.0
	dashes_remaining = max_air_dashes
	dash_timer = 0.0
	dash_elapsed = 0.0
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	if is_crouching:
		is_crouching = false
		apply_stand_visuals()
	if is_sliding:
		end_slide()
	reset_climb_state()

func exit_trap() -> void:
	is_trapped = false

func run_water(delta: float) -> void:
	if dash_buffer_timer > 0.0 and dash_cooldown_timer <= 0.0:
		start_water_dash()

	if dash_timer > 0.0:
		run_water_dash(delta)
	else:
		var target_vel = input_dir * water_swim_speed
		if input_dir == Vector2.ZERO:
			velocity = velocity.move_toward(Vector2.ZERO, water_swim_drag * delta)
		else:
			velocity = velocity.move_toward(target_vel, water_swim_accel * delta)
		
		if velocity.length() > 0.1:
			velocity.y += water_gravity * delta

func start_water_dash() -> void:
	dash_buffer_timer = 0.0
	dash_cooldown_timer = dash_cooldown

	var dir := input_dir
	if dir == Vector2.ZERO:
		dir = Vector2(facing, 0.0)

	dash_dir = dir.normalized()
	if dash_dir == Vector2.ZERO:
		dash_dir = Vector2(facing, 0.0)

	dash_timer = dash_time * 0.8
	dash_elapsed = 0.0
	velocity = dash_dir * water_dash_speed

func run_water_dash(delta: float) -> void:
	dash_elapsed += delta
	dash_timer -= delta
	
	var progress = dash_elapsed / (dash_time * 0.8)
	var speed_multiplier = 1.0
	if progress > 0.2:
		var brake_progress = (progress - 0.2) / 0.8
		speed_multiplier = 1.0 - (brake_progress * brake_progress * 0.9)
	
	var target_vel = dash_dir * (water_dash_speed * speed_multiplier)
	velocity = velocity.move_toward(target_vel, water_dash_drag * delta)
	
	if dash_timer <= 0.0:
		dash_timer = 0.0

func enter_water() -> void:
	is_in_water = true
	if dash_timer > 0.0:
		dash_timer *= 0.5
		dash_dir = velocity.normalized()
		if dash_dir == Vector2.ZERO:
			dash_dir = Vector2(facing, 0.0)
	reset_climb_state()
	if is_sliding:
		end_slide()
	if is_crouching:
		is_crouching = false
		apply_stand_visuals()

func exit_water() -> void:
	is_in_water = false

func update_stamina(delta: float) -> void:
	if is_in_water or is_trapped:
		return
	if is_climbing:
		var climb_y := input_dir.y
		if climb_y < 0.0:
			current_stamina = maxf(current_stamina - stamina_climb_up_rate * delta, 0.0)
		elif climb_y > 0.0:
			current_stamina = maxf(current_stamina - stamina_climb_down_rate * delta, 0.0)
		else:
			current_stamina = maxf(current_stamina - stamina_drain_rate * delta, 0.0)
	elif is_on_floor() and not is_sliding and not is_crouching:
		current_stamina = minf(current_stamina + stamina_regen_rate * delta, max_stamina)

func update_stamina_bar() -> void:
	if not stamina_bar:
		return
	if original_stamina_bar_width == 0.0:
		original_stamina_bar_width = stamina_bar.size.x
	stamina_bar.size.x = original_stamina_bar_width * (current_stamina / max_stamina)
	if dashes_remaining > 0:
		stamina_bar.color = stamina_color
	else:
		stamina_bar.color = stamina_no_dash_color

func update_crouch_state() -> void:
	var want_crouch := is_on_floor() and not is_sliding and input_dir.y > 0.5
	if want_crouch == is_crouching:
		return
	is_crouching = want_crouch
	if want_crouch:
		apply_crouch_visuals()
	else:
		apply_stand_visuals()

func reset_climb_state() -> void:
	is_climbing = false
	climb_wall_side = 0
	climb_lost_timer = 0.0
	climbing_platform = null

func get_input_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func update_wall_contact() -> void:
	touch_wall_side = 0
	if is_on_wall_only():
		var normal := get_wall_normal()
		if absf(normal.y) < 0.9:
			touch_wall_side = -int(signf(normal.x))

func find_wall_collider() -> Object:
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if absf(collision.get_normal().y) < 0.9:
			return collision.get_collider()
	return null

func update_climb_state(delta: float) -> void:
	if current_stamina <= 0.0 or is_on_floor() or is_on_ceiling() or dash_timer > 0.0:
		reset_climb_state()
		return

	var holding_grab := Input.is_action_pressed("grab")
	var is_sliding := touch_wall_side != 0 and velocity.y > wall_slide_speed

	if is_climbing:
		if not holding_grab:
			reset_climb_state()
		elif touch_wall_side != 0:
			climb_wall_side = touch_wall_side
			climb_lost_timer = climb_contact_grace
			var collider = find_wall_collider()
			climbing_platform = collider if collider and collider.has_method("get_platform_velocity") else null
		else:
			climb_lost_timer -= delta
			if climb_lost_timer <= 0.0:
				reset_climb_state()
		return

	if (holding_grab or is_sliding) and touch_wall_side != 0 and climb_lockout_timer <= 0.0:
		is_climbing = true
		climb_wall_side = touch_wall_side
		climb_lost_timer = climb_contact_grace
		var collider = find_wall_collider()
		climbing_platform = collider if collider and collider.has_method("get_platform_velocity") else null

func start_dash() -> void:
	dash_buffer_timer = 0.0
	dash_recharge_timer = 1.2
	dash_cooldown_timer = dash_cooldown
	dashes_remaining -= 1
	reset_climb_state()

	var dir := input_dir
	if dir == Vector2.ZERO:
		dir = Vector2(facing, 0.0)
	if is_on_floor() and dir.y > 0.0:
		dir.y = 0.0

	dash_dir = dir.normalized()
	if dash_dir == Vector2.ZERO:
		dash_dir = Vector2(facing, 0.0)

	if is_crouching and is_on_floor():
		start_slide()
	else:
		dash_timer = dash_time
		dash_elapsed = 0.0
		velocity = dash_dir * dash_speed
		if is_on_floor() and absf(dash_dir.y) < 0.1:
			velocity.y = 0.0

func start_slide() -> void:
	is_sliding = true
	slide_timer = 0.0
	var slide_dir := Vector2(signf(input_dir.x) if input_dir.x != 0.0 else facing, 0.0)
	velocity = slide_dir * slide_speed

func run_slide(delta: float) -> void:
	slide_timer += delta
	if velocity.length() < slide_min_speed:
		end_slide()
		return
	
	var is_touching_surface = is_on_floor()
	if is_touching_surface:
		var normal := get_floor_normal()
		var slope_factor := 1.0 - absf(normal.y)
		var slope_direction := Vector2(normal.x, 0.0).normalized()
		if slope_direction.x * velocity.x > 0.0 and slope_factor > 0.05:
			velocity.x += slope_direction.x * slope_factor * 2000.0 * delta
		velocity.x = move_toward(velocity.x, 0.0, slide_friction * delta)
	else:
		velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, air_friction * delta)

func end_slide() -> void:
	is_sliding = false
	slide_timer = 0.0

func do_jump() -> void:
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	dash_timer = 0.0
	if is_sliding:
		end_slide()
	if is_crouching:
		is_crouching = false
		apply_stand_visuals()

	var wall_side := climb_wall_side if is_climbing else touch_wall_side
	if not is_on_floor() and wall_side != 0:
		velocity.x = -wall_side * wall_jump_x_force
		velocity.y = -wall_jump_y_force
		reset_climb_state()
		climb_lockout_timer = wall_jump_lockout
	else:
		velocity.y = jump_velocity

func run_dash(delta: float) -> void:
	dash_elapsed += delta
	dash_timer -= delta
	
	var progress = dash_elapsed / dash_time
	var speed_multiplier = 1.0
	if progress > 0.7:
		var brake_progress = (progress - 0.7) / 0.3
		speed_multiplier = 1.0 - (brake_progress * brake_progress * 0.5)
	
	velocity = dash_dir * (dash_speed * speed_multiplier)

	if is_on_floor() and dash_dir.y > 0.0:
		dash_timer = 0.0
		velocity.y = 0.0
	elif is_on_ceiling() and dash_dir.y < 0.0:
		dash_timer = 0.0
		velocity.y = 0.0

func run_climb(delta: float) -> void:
	var climb_y := input_dir.y
	var target_y := 0.0
	if climb_y < 0.0:
		target_y = climb_y * climb_up_speed
	elif climb_y > 0.0:
		target_y = climb_y * climb_down_speed
	else:
		target_y = grab_slide_speed

	velocity.y = move_toward(velocity.y, target_y, climb_accel * delta)
	
	if climbing_platform:
		var plat_vel = climbing_platform.get_platform_velocity()
		velocity.x = (climb_wall_side * wall_stick_speed) + plat_vel.x
		velocity.y = plat_vel.y
	else:
		velocity.x = climb_wall_side * wall_stick_speed

func run_normal(delta: float) -> void:
	var on_floor := is_on_floor()
	var accel := ground_accel if on_floor else air_accel
	var friction := ground_friction if on_floor else air_friction
	var current_speed := crouch_speed if is_crouching else run_speed

	if on_floor:
		var normal := get_floor_normal()
		var slope_angle := rad_to_deg(atan2(normal.x, -normal.y))
		if absf(slope_angle) > 15.0:
			var slope_factor := 1.0 - absf(normal.y)
			var slide_force := 1200.0 * slope_factor * (2.5 if is_crouching else 1.0)
			velocity.x += signf(normal.x) * slide_force * delta
			velocity.y += gravity * 2.0 * delta
		elif velocity.y > 0.0:
			velocity.y = 0.0
	else:
		var current_gravity := gravity
		if velocity.y > 0.0:
			current_gravity *= 1.25
			if input_dir.y > 0.0 and touch_wall_side == 0:
				current_gravity *= 1.3
		if spring_gravity_timer > 0.0:
			current_gravity *= spring_gravity_multiplier
		velocity.y = minf(velocity.y + current_gravity * delta, max_fall_speed)

	if touch_wall_side != 0 and velocity.y > 0.0 and not is_climbing:
		velocity.y = move_toward(velocity.y, 100.0, wall_slide_accel * delta)

	if input_dir.x != 0.0:
		var target_x := input_dir.x * current_speed
		var accel_value := 1200.0 if (absf(velocity.x) > current_speed and velocity.x * input_dir.x > 0.0) else accel
		velocity.x = move_toward(velocity.x, target_x, accel_value * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

func apply_spring_bounce(bounce_velocity: Vector2) -> void:
	velocity = bounce_velocity
	reset_climb_state()
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	dash_recharge_timer = 0.0
	dashes_remaining = max_air_dashes
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	spring_gravity_timer = spring_gravity_duration
	if is_sliding:
		end_slide()
	if is_crouching:
		is_crouching = false
		apply_stand_visuals()
	if absf(velocity.x) > 0.1:
		facing = 1 if velocity.x > 0.0 else -1

func apply_crouch_visuals() -> void:
	var collision_shape := get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.extents = crouch_collision_extents
	
	var color_rect := get_node_or_null("ColorRect")
	if color_rect:
		color_rect.size = crouch_color_rect_size
		color_rect.position = crouch_color_rect_position

func apply_stand_visuals() -> void:
	var collision_shape := get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.extents = original_collision_extents
	
	var color_rect := get_node_or_null("ColorRect")
	if color_rect:
		color_rect.size = original_color_rect_size
		color_rect.position = original_color_rect_position
