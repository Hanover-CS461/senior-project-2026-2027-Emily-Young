extends CharacterBody3D

const WALK_SPEED = 2.0
const RUN_SPEED = 4.0
const JUMP_VELOCITY = 4.5
const CAMERA_SENSITIVITY = 1

@onready var animation_player = $Knight/AnimationPlayer
@onready var camera_pivot = $CameraPivot

var current_animation = ""
var is_jumping = false
var is_landing = false

var health = 100

var attack_damage = 20
var attack_cooldown = 1.0
var attack_timer = 0.0
var is_attacking = false

var attack_range = 1.5


func _ready():
	play_animation("Rig_Medium_General/Idle_A")


func play_animation(animation_name: String):
	if current_animation != animation_name:
		animation_player.play(animation_name)
		current_animation = animation_name


func _physics_process(delta):

	# --------------------------------------------------
	# ATTACK TIMER
	# --------------------------------------------------

	if attack_timer > 0:
		attack_timer -= delta


	# --------------------------------------------------
	# START ATTACK
	# --------------------------------------------------

	if Input.is_action_just_pressed("p2_attack") and attack_timer <= 0 and not is_attacking:

		attack()

		return


	# --------------------------------------------------
	# CURRENT ATTACK
	# --------------------------------------------------

	if is_attacking:

		var attack_length = animation_player.current_animation_length
		var attack_position = animation_player.current_animation_position

		# Wait until the Throw animation finishes
		if attack_position < attack_length:
			return

		# Animation has finished
		var enemies = get_tree().get_nodes_in_group("enemies")

		for enemy in enemies:

			var distance = global_position.distance_to(
				enemy.global_position
			)

			if distance <= attack_range:

				if enemy.has_method("take_damage"):
					enemy.take_damage(attack_damage)

				print("Knight hits enemy!")

			else:

				print("Knight missed!")


		# Finish the attack
		is_attacking = false
		attack_timer = attack_cooldown

		return


	# --------------------------------------------------
	# CAMERA CONTROLS
	# --------------------------------------------------

	var look_x = Input.get_axis("p2_look_left", "p2_look_right")
	var look_y = Input.get_axis("p2_look_up", "p2_look_down")

	# Rotate Player 2 left/right
	rotate_y(-look_x * CAMERA_SENSITIVITY * delta)

	# Rotate camera up/down
	camera_pivot.rotate_x(look_y * CAMERA_SENSITIVITY * delta)

	# Prevent the camera from looking too far up/down
	camera_pivot.rotation.x = clamp(
		camera_pivot.rotation.x,
		-0.4,
		0.4
	)


	# --------------------------------------------------
	# GRAVITY
	# --------------------------------------------------

	if not is_on_floor():
		velocity += get_gravity() * delta


	# --------------------------------------------------
	# MOVEMENT INPUT
	# --------------------------------------------------

	var direction = Vector3.ZERO

	# UP = forward
	if Input.is_action_pressed("p2_forward"):
		direction.z += 1

	# DOWN = backward
	if Input.is_action_pressed("p2_backward"):
		direction.z -= 1

	# LEFT = left
	if Input.is_action_pressed("p2_left"):
		direction.x += 1

	# RIGHT = right
	if Input.is_action_pressed("p2_right"):
		direction.x -= 1


	# Prevent diagonal movement from being faster
	if direction.length() > 0:
		direction = direction.normalized()

		# Movement follows Player 2's rotation
		direction = transform.basis * direction


	# --------------------------------------------------
	# JUMP
	# --------------------------------------------------

	if Input.is_action_just_pressed("p2_jump") and is_on_floor() and not is_landing:

		velocity.y = JUMP_VELOCITY
		is_jumping = true

		play_animation("Rig_Medium_MovementBasic/Jump_Start")


	# --------------------------------------------------
	# HORIZONTAL MOVEMENT
	# --------------------------------------------------

	if direction.length() > 0:

		# Running
		if Input.is_action_pressed("p2_run"):

			velocity.x = direction.x * RUN_SPEED
			velocity.z = direction.z * RUN_SPEED

			if not is_jumping and not is_landing:
				play_animation("Rig_Medium_MovementBasic/Running_B")

		# Walking
		else:

			velocity.x = direction.x * WALK_SPEED
			velocity.z = direction.z * WALK_SPEED

			if not is_jumping and not is_landing:
				play_animation("Rig_Medium_MovementBasic/Walking_B")

	else:

		velocity.x = 0
		velocity.z = 0

		if not is_jumping and not is_landing:
			play_animation("Rig_Medium_General/Idle_A")


	# --------------------------------------------------
	# MOVE
	# --------------------------------------------------

	move_and_slide()


	# --------------------------------------------------
	# LANDING
	# --------------------------------------------------

	if is_jumping and is_on_floor():

		is_jumping = false
		is_landing = true

		play_animation("Rig_Medium_MovementBasic/Jump_Land")


	# --------------------------------------------------
	# LANDING ANIMATION
	# --------------------------------------------------

	if is_landing:

		var landing_length = animation_player.current_animation_length
		var landing_position = animation_player.current_animation_position

		# Switch slightly before the landing animation ends
		if landing_position < landing_length - 0.08:
			return

		is_landing = false

		# Choose the appropriate animation
		if direction.length() > 0:

			if Input.is_action_pressed("p2_run"):
				play_animation("Rig_Medium_MovementBasic/Running_B")
			else:
				play_animation("Rig_Medium_MovementBasic/Walking_B")

		else:

			play_animation("Rig_Medium_General/Idle_A")


# --------------------------------------------------
# ATTACK FUNCTION
# --------------------------------------------------

func attack():

	print("Knight attacks!")

	is_attacking = true

	play_animation("Rig_Medium_General/Throw")


# --------------------------------------------------
# HEALTH / DAMAGE
# --------------------------------------------------

func take_damage(amount):

	health -= amount

	print("Player 2 health: ", health)

	if health <= 0:

		print("Player 2 defeated!")
