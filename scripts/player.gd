class_name FastParkourPlayer
extends CharacterBody2D

@export var run_speed := 390.0
@export var ground_accel := 3000.0
@export var air_accel := 2200.0
@export var ground_friction := 2800.0
@export var air_friction := 420.0
@export var dash_carry_friction := 950.0
@export var jump_velocity := -680.0
@export var gravity := 1900.0
@export var fall_gravity_multiplier := 1.35
@export var fast_fall_gravity_multiplier := 1.35
@export var max_fall_speed := 1100.0
@export var coyote_time := 0.09
@export var jump_buffer_time := 0.14
@export var jump_cut_multiplier := 0.45
@export var dash_speed := 780.0
@export var dash_time := 0.14
@export var dash_cooldown := 0.06
@export var dash_buffer_time := 0.14
@export var dash_end_multiplier := 0.55
@export var max_air_dashes := 1

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

	if is_on_floor():
		coyote_timer = coyote_time
		dashes_remaining = max_air_dashes
	else:
		if dash_timer <= 0.0:
			coyote_timer = maxf(coyote_timer - delta, 0.0)

	if dash_buffer_timer > 0.0 and dash_timer <= 0.0 and dash_cooldown_timer <= 0.0 and dashes_remaining > 0:
		start_dash()

	var can_jump := jump_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0)
	var can_interrupt_dash := dash_timer <= 0.0 or dash_elapsed > 0.05
	if can_jump and can_interrupt_dash:
		do_jump()

	if dash_timer > 0.0:
		run_dash(delta)
	else:
		run_normal(delta)

	move_and_slide()

	if is_on_floor():
		dashes_remaining = max_air_dashes
		coyote_timer = coyote_time

func get_input_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func start_dash() -> void:
	dash_buffer_timer = 0.0
	dash_timer = dash_time
	dash_elapsed = 0.0
	dash_cooldown_timer = dash_cooldown
	dashes_remaining -= 1

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
	velocity.y = jump_velocity

func run_dash(delta: float) -> void:
	dash_elapsed += delta
	dash_timer -= delta
	velocity = dash_dir * dash_speed

	var ended_naturally := dash_timer <= 0.0

	if is_on_floor() and dash_dir.y > 0.0:
		dash_timer = 0.0
		ended_naturally = false
		velocity.y = 0.0
		velocity.x = dash_dir.x * dash_speed * dash_end_multiplier

	if is_on_ceiling() and dash_dir.y < 0.0:
		dash_timer = 0.0
		ended_naturally = false
		velocity.y = 0.0
		velocity.x *= dash_end_multiplier

	if ended_naturally:
		velocity *= dash_end_multiplier

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
			if input_dir.y > 0.0:
				current_gravity *= fast_fall_gravity_multiplier
		velocity.y = minf(velocity.y + current_gravity * delta, max_fall_speed)
