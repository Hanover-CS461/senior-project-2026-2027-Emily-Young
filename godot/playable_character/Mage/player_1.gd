extends CharacterBody3D


const WALK_SPEED = 2.0
const RUN_SPEED = 4.0
const JUMP_VELOCITY = 4.5


@export var mouse_sensitivity = 0.002
@export var joystick_camera_sensitivity = 2.0
@export var camera_dead_zone = 0.08
@export var look_up_down_limit = 0.4


@onready var camera_pivot = $CameraPivot
@onready var animation_player = $Mage/AnimationPlayer


var current_animation = ""
var is_jumping = false
var is_landing = false
var is_hit = false
var is_dead = false


var health = 100


var arduino


func _ready():

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	play_animation(
		"Rig_Medium_General/Idle_A"
	)

	arduino = ArduinoMage


func play_animation(animation_name: String):

	if current_animation != animation_name:

		animation_player.play(animation_name)

		current_animation = animation_name


func _input(event):

	# ==========================================
	# ESCAPE
	# ==========================================

	if event.is_action_pressed("ui_cancel"):

		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		return


	# ==========================================
	# DEAD
	# ==========================================

	if is_dead:

		return


	# ==========================================
	# MOUSE CAMERA
	# ==========================================

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:

		rotate_y(
			-event.relative.x * mouse_sensitivity
		)

		camera_pivot.rotate_x(
			event.relative.y * mouse_sensitivity
		)

		camera_pivot.rotation.x = clamp(
			camera_pivot.rotation.x,
			-look_up_down_limit,
			look_up_down_limit
		)


	# ==========================================
	# CAPTURE MOUSE
	# ==========================================

	if event is InputEventMouseButton and event.pressed:

		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta):


	# ==========================================
	# GRAVITY
	# ==========================================

	if not is_on_floor():

		velocity += get_gravity() * delta


	# ==========================================
	# DEAD
	# ==========================================

	if is_dead:

		velocity.x = 0
		velocity.z = 0

		move_and_slide()

		return


	# ==========================================
	# HIT ANIMATION
	# ==========================================

	if is_hit:

		var hit_length = animation_player.current_animation_length

		var hit_position = animation_player.current_animation_position


		if hit_position >= hit_length:

			is_hit = false


	# ==========================================
	# ARDUINO CAMERA
	# ==========================================

	if arduino != null:

		var camera_x = arduino.camera_x
		var camera_y = arduino.camera_y


		if abs(camera_x) < camera_dead_zone:

			camera_x = 0.0


		if abs(camera_y) < camera_dead_zone:

			camera_y = 0.0


		rotate_y(
			-camera_x * joystick_camera_sensitivity * delta
		)


		camera_pivot.rotate_x(
			camera_y * joystick_camera_sensitivity * delta
		)


		camera_pivot.rotation.x = clamp(
			camera_pivot.rotation.x,
			-look_up_down_limit,
			look_up_down_limit
		)


	# ==========================================
	# MOVEMENT
	# ==========================================

	var direction = Vector3.ZERO

	var joystick_x = 0.0
	var joystick_y = 0.0


	if arduino != null:

		joystick_x = arduino.joystick_x
		joystick_y = arduino.joystick_y


	direction.x = -joystick_x
	direction.z = -joystick_y


	# ==========================================
	# KEYBOARD MOVEMENT
	# ==========================================

	if Input.is_action_pressed("move_forward"):

		direction.z += 1


	if Input.is_action_pressed("move_backward"):

		direction.z -= 1


	if Input.is_action_pressed("move_left"):

		direction.x += 1


	if Input.is_action_pressed("move_right"):

		direction.x -= 1


	if direction.length() > 1.0:

		direction = direction.normalized()


	if direction.length() > 0:

		direction = transform.basis * direction


	# ==========================================
	# JUMP
	# ==========================================

	var jump_requested = Input.is_action_just_pressed("jump")


	if arduino != null and arduino.jump_pressed:

		jump_requested = true

		arduino.jump_pressed = false


	if (
		jump_requested
		and is_on_floor()
		and not is_landing
		and not is_hit
	):

		velocity.y = JUMP_VELOCITY

		is_jumping = true

		play_animation(
			"Rig_Medium_MovementBasic/Jump_Start"
		)


	# ==========================================
	# MOVEMENT SPEED
	# ==========================================

	if direction.length() > 0:

		var should_run = false


		# ==========================================
		# KEYBOARD SPRINT
		# ==========================================

		if Input.is_action_pressed("run"):

			should_run = true


		# ==========================================
		# ARDUINO L3 SPRINT
		# ==========================================

		if arduino != null and arduino.sprint_pressed:

			should_run = true


		# ==========================================
		# RUNNING
		# ==========================================

		if should_run:

			velocity.x = direction.x * RUN_SPEED
			velocity.z = direction.z * RUN_SPEED


			if (
				not is_jumping
				and not is_landing
				and not is_hit
			):

				play_animation(
					"Rig_Medium_MovementBasic/Running_A"
				)


		# ==========================================
		# WALKING
		# ==========================================

		else:

			velocity.x = direction.x * WALK_SPEED
			velocity.z = direction.z * WALK_SPEED


			if (
				not is_jumping
				and not is_landing
				and not is_hit
			):


				# ==========================================
				# WALKING FORWARD
				# ==========================================

				if joystick_y < -0.15:

					play_animation(
						"Rig_Medium_MovementBasic/Walking_C"
					)


				# ==========================================
				# WALKING BACKWARD
				# ==========================================

				elif joystick_y > 0.15:

					play_animation(
						"Rig_Medium_MovementAdvanced/Walking_Backwards"
					)


				# ==========================================
				# SIDEWAYS
				# ==========================================

				else:

					play_animation(
						"Rig_Medium_MovementBasic/Walking_C"
					)


	else:

		velocity.x = 0
		velocity.z = 0


		if (
			not is_jumping
			and not is_landing
			and not is_hit
		):

			play_animation(
				"Rig_Medium_General/Idle_A"
			)


	# ==========================================
	# MOVE
	# ==========================================

	move_and_slide()


	# ==========================================
	# LANDING
	# ==========================================

	if is_jumping and is_on_floor():

		is_jumping = false

		is_landing = true

		play_animation(
			"Rig_Medium_MovementBasic/Jump_Land"
		)


	# ==========================================
	# LANDING ANIMATION
	# ==========================================

	if is_landing:

		var landing_length = animation_player.current_animation_length

		var landing_position = animation_player.current_animation_position


		if landing_position < landing_length - 0.35:

			return


		is_landing = false


		if direction.length() > 0:

			if Input.is_action_pressed("run") or (
				arduino != null and arduino.sprint_pressed
			):

				play_animation(
					"Rig_Medium_MovementBasic/Running_A"
				)

			else:

				# ==========================================
				# LANDING WHILE MOVING FORWARD
				# ==========================================

				if joystick_y < -0.15:

					play_animation(
						"Rig_Medium_MovementBasic/Walking_C"
					)


				# ==========================================
				# LANDING WHILE MOVING BACKWARD
				# ==========================================

				elif joystick_y > 0.15:

					play_animation(
						"Rig_Medium_MovementAdvanced/Walking_Backwards"
					)


				# ==========================================
				# LANDING WHILE MOVING SIDEWAYS
				# ==========================================

				else:

					play_animation(
						"Rig_Medium_MovementBasic/Walking_C"
					)

		else:

			play_animation(
				"Rig_Medium_General/Idle_A"
			)


# ==========================================
# HEALTH / DAMAGE
# ==========================================

func take_damage(amount):

	if is_dead:

		return


	health -= amount


	print(
		"Player 1 health: ",
		health
	)


	# ==========================================
	# DEATH
	# ==========================================

	if health <= 0:

		health = 0

		is_dead = true
		is_hit = false
		is_jumping = false
		is_landing = false

		velocity = Vector3.ZERO

		animation_player.stop()

		current_animation = ""

		animation_player.play(
			"Rig_Medium_General/Death_B"
		)

		current_animation = (
			"Rig_Medium_General/Death_B"
		)

		print(
			"Player 1 defeated!"
		)

		return


	# ==========================================
	# NORMAL HIT
	# ==========================================

	is_hit = true

	play_animation(
		"Rig_Medium_General/Hit_A"
	)
