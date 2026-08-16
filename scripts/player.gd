class_name FastParkourPlayer
extends CharacterBody2D

@export var run_speed := 360.0
@export var ground_accel := 2800.0
@export var air_accel := 2000.0
@export var ground_friction := 2400.0
@export var air_friction := 500.0
@export var dash_carry_friction := 1200.0
@export var jump_velocity := -620.0
@export var gravity := 1800.0
@export var fall_gravity_multiplier := 1.25
@export var fast_fall_gravity_multiplier := 1.3
@export var max_fall_speed := 900.0
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.15
@export var jump_cut_multiplier := 0.5
@export var dash_speed := 720.0
@export var dash_time := 0.16
@export var dash_cooldown := 0.08
@export var dash_buffer_time := 0.15
@export var dash_end_multiplier := 0.65
@export var max_air_dashes := 1
@export var climb_up_speed := 100.0
@export var climb_down_speed := 180.0
@export var climb_accel := 1600.0
@export var wall_stick_speed := 120.0
@export var wall_slide_speed := 120.0
@export var wall_slide_accel := 3500.0
@export var wall_jump_x_force := 330.0
@export var wall_jump_y_force := 600.0
@export var wall_jump_lockout := 0.1
@export var invert_climb_input := false
@export var climb_contact_grace := 0.08

var input_dir := Vector2.ZERO
var facing := 1
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var dash_buffer_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_timer := 0.0
var dash_elapsed := 0.0
var dash_dir := Vector2.RIGHT
var dashes_remaining := 1
var is_climbing := false
var climb_wall_side := 0
var touch_wall_side := 0
var climb_lockout_timer := 0.0
var climb_lost_timer := 0.0

func _ready() -> void:
	dashes_remaining = max_air_dashes

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
	climb_lockout_timer = maxf(climb_lockout_timer - delta, 0.0)

	update_wall_contact()
	update_climb_state(delta)

	if is_on_floor():
		coyote_timer = coyote_time
		dashes_remaining = max_air_dashes
	else:
		if dash_timer <= 0.0 and not is_climbing:
			coyote_timer = maxf(coyote_timer - delta, 0.0)

	if dash_buffer_timer > 0.0 and dash_timer <= 0.0 and dash_cooldown_timer <= 0.0 and dashes_remaining > 0:
		start_dash()

	var can_wall_jump := touch_wall_side != 0 and not is_on_floor()
	var can_jump := jump_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0 or is_climbing or can_wall_jump)
	var can_interrupt_dash := dash_timer <= 0.0 or dash_elapsed > 0.06
	if can_jump and can_interrupt_dash:
		do_jump()

	if dash_timer > 0.0:
		run_dash(delta)
	elif is_climbing:
		run_climb(delta)
	else:
		run_normal(delta)

	move_and_slide()

	if is_on_floor():
		dashes_remaining = max_air_dashes
		coyote_timer = coyote_time

func get_input_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func update_wall_contact() -> void:
	touch_wall_side = 0
	if is_on_wall_only():
		var normal := get_wall_normal()
		if absf(normal.y) < 0.9:
			touch_wall_side = -int(signf(normal.x))

func update_climb_state(delta: float) -> void:
	if is_on_floor() or is_on_ceiling() or dash_timer > 0.0:
		is_climbing = false
		climb_wall_side = 0
		climb_lost_timer = 0.0
		return

	var holding_grab := Input.is_action_pressed("grab")

	if is_climbing:
		if not holding_grab:
			is_climbing = false
			climb_wall_side = 0
			climb_lost_timer = 0.0
		else:
			if touch_wall_side != 0:
				climb_wall_side = touch_wall_side
				climb_lost_timer = climb_contact_grace
			else:
				climb_lost_timer -= delta
				if climb_lost_timer <= 0.0:
					is_climbing = false
					climb_wall_side = 0
		return

	if holding_grab and touch_wall_side != 0 and climb_lockout_timer <= 0.0:
		is_climbing = true
		climb_wall_side = touch_wall_side
		climb_lost_timer = climb_contact_grace

func start_dash() -> void:
	dash_buffer_timer = 0.0
	dash_timer = dash_time
	dash_elapsed = 0.0
	dash_cooldown_timer = dash_cooldown
	dashes_remaining -= 1
	is_climbing = false
	climb_wall_side = 0
	climb_lost_timer = 0.0

	var dir := input_dir
	if dir == Vector2.ZERO:
		dir = Vector2(facing, 0.0)

	if is_on_floor() and dir.y > 0.0:
		dir.y = 0.0

	dash_dir = dir.normalized()
	if dash_dir == Vector2.ZERO:
		dash_dir = Vector2(facing, 0.0)

	velocity = dash_dir * dash_speed

	if is_on_floor() and absf(dash_dir.y) < 0.1:
		velocity.y = 0.0

func do_jump() -> void:
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	dash_timer = 0.0

	var wall_side := climb_wall_side if is_climbing else touch_wall_side

	if not is_on_floor() and wall_side != 0:
		velocity.x = -wall_side * wall_jump_x_force
		velocity.y = -wall_jump_y_force
		is_climbing = false
		climb_wall_side = 0
		climb_lockout_timer = wall_jump_lockout
		climb_lost_timer = 0.0
	else:
		velocity.y = jump_velocity

func run_dash(delta: float) -> void:
	dash_elapsed += delta
	dash_timer -= delta
	velocity = dash_dir * dash_speed

	if is_on_floor() and dash_dir.y > 0.0:
		dash_timer = 0.0
		velocity.y = 0.0
		velocity.x *= dash_end_multiplier
	elif is_on_ceiling() and dash_dir.y < 0.0:
		dash_timer = 0.0
		velocity.y = 0.0
		velocity.x *= dash_end_multiplier
	elif dash_timer <= 0.0:
		velocity *= dash_end_multiplier

func run_climb(delta: float) -> void:
	var climb_y := input_dir.y
	if invert_climb_input:
		climb_y = -climb_y

	var target_y := 0.0
	if climb_y < 0.0:
		target_y = climb_y * climb_up_speed
	elif climb_y > 0.0:
		target_y = climb_y * climb_down_speed

	velocity.y = move_toward(velocity.y, target_y, climb_accel * delta)
	velocity.x = climb_wall_side * wall_stick_speed

func run_normal(delta: float) -> void:
	var on_floor := is_on_floor()
	var accel := ground_accel if on_floor else air_accel
	var friction := ground_friction if on_floor else air_friction

	if input_dir.x != 0.0:
		var target_x := input_dir.x * run_speed
		if absf(velocity.x) > run_speed and velocity.x * input_dir.x > 0.0:
			velocity.x = move_toward(velocity.x, target_x, dash_carry_friction * delta)
		else:
			velocity.x = move_toward(velocity.x, target_x, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if on_floor:
		if velocity.y > 0.0:
			velocity.y = 0.0
	else:
		var current_gravity := gravity
		if velocity.y > 0.0:
			current_gravity *= fall_gravity_multiplier
			if input_dir.y > 0.0 and touch_wall_side == 0:
				current_gravity *= fast_fall_gravity_multiplier
		velocity.y = minf(velocity.y + current_gravity * delta, max_fall_speed)
		if touch_wall_side != 0 and velocity.y > wall_slide_speed:
			velocity.y = move_toward(velocity.y, wall_slide_speed, wall_slide_accel * delta)
