extends CharacterBody3D


const WALK_SPEED = 2.0
const RUN_SPEED = 4.0
const JUMP_VELOCITY = 4.5
const CAMERA_SENSITIVITY = 2.5
const VERTICAL_CAMERA_SENSITIVITY = 1.5


@onready var animation_player = $Knight/AnimationPlayer
@onready var camera_pivot = $CameraPivot
@onready var arduino_knight = ArduinoKnight


var current_animation = ""

var is_jumping = false
var is_landing = false
var is_hit = false
var is_dead = false


var health = 100


var attack_damage = 20
var attack_cooldown = 1.0
var attack_timer = 0.0
var is_attacking = false
var attack_range = 1.5


var is_shielding = false
var shield_starting = false
var is_blocking_hit = false


func _ready():

	play_animation(
		"Rig_Medium_General/Idle_A"
	)


func play_animation(animation_name: String):

	if current_animation != animation_name:

		animation_player.play(animation_name)

		current_animation = animation_name


func _physics_process(delta):

	# ==========================================
	# DEAD
	# ==========================================

	if is_dead:

		velocity.x = 0
		velocity.z = 0

		if not is_on_floor():

			velocity += get_gravity() * delta

		move_and_slide()

		return


	# ==========================================
	# ATTACK TIMER
	# ==========================================

	if attack_timer > 0:

		attack_timer -= delta


	# ==========================================
	# SHIELD
	# ==========================================

	if (
		arduino_knight.shield
		and not is_attacking
		and not is_jumping
		and not is_landing
		and not is_hit
	):

		if not is_shielding:

			is_shielding = true
			shield_starting = true

			play_animation(
				"Rig_Medium_CombatMelee/Melee_Block"
			)


		elif shield_starting:

			var block_length = (
				animation_player.current_animation_length
			)

			var block_position = (
				animation_player.current_animation_position
			)

			if block_position >= block_length - 0.05:

				shield_starting = false

				play_animation(
					"Rig_Medium_CombatMelee/Melee_Blocking"
				)


		elif not is_blocking_hit:

			play_animation(
				"Rig_Medium_CombatMelee/Melee_Blocking"
			)


	else:

		if is_shielding and not arduino_knight.shield:

			is_shielding = false
			shield_starting = false
			is_blocking_hit = false


	# ==========================================
	# HIT ANIMATION
	# ==========================================

	if is_hit:

		var hit_length = (
			animation_player.current_animation_length
		)

		var hit_position = (
			animation_player.current_animation_position
		)

		if hit_position >= hit_length:

			is_hit = false


	# ==========================================
	# ATTACK INPUT
	# ==========================================

	if (
		(
			Input.is_action_just_pressed("p2_attack")
			or arduino_knight.attack_pressed
		)
		and attack_timer <= 0
		and not is_attacking
		and not is_hit
	):

		arduino_knight.attack_pressed = false

		attack()

		return


	# ==========================================
	# ATTACKING
	# ==========================================

	if is_attacking:

		var attack_length = (
			animation_player.current_animation_length
		)

		var attack_position = (
			animation_player.current_animation_position
		)

		if attack_position < attack_length:

			return


		var enemies = (
			get_tree().get_nodes_in_group("enemies")
		)

		var hit_enemy = false


		for enemy in enemies:

			var distance = (
				global_position.distance_to(
					enemy.global_position
				)
			)


			if distance <= attack_range:

				if enemy.has_method("take_damage"):

					enemy.take_damage(
						attack_damage
					)

					print(
						"Knight hits enemy!"
					)

					hit_enemy = true

					break


		if not hit_enemy:

			print(
				"Knight missed!"
			)


		is_attacking = false

		attack_timer = attack_cooldown


		if arduino_knight.shield:

			is_shielding = true
			shield_starting = false

			play_animation(
				"Rig_Medium_CombatMelee/Melee_Blocking"
			)


		return


	# ==========================================
	# SHIELD HIT
	# ==========================================

	if is_blocking_hit:

		var block_hit_length = (
			animation_player.current_animation_length
		)

		var block_hit_position = (
			animation_player.current_animation_position
		)


		if block_hit_position >= block_hit_length:

			is_blocking_hit = false


			if arduino_knight.shield:

				play_animation(
					"Rig_Medium_CombatMelee/Melee_Blocking"
				)


	# ==========================================
	# CAMERA
	# ==========================================

	var look = arduino_knight.get_look()


	if look.length() > 0:

		rotate_y(
			-look.x
			* CAMERA_SENSITIVITY
			* delta
		)


		camera_pivot.rotate_x(
			-look.y
			* VERTICAL_CAMERA_SENSITIVITY
			* delta
		)


		camera_pivot.rotation.x = clamp(
			camera_pivot.rotation.x,
			-0.4,
			0.4
		)


	# ==========================================
	# GRAVITY
	# ==========================================

	if not is_on_floor():

		velocity += get_gravity() * delta


	# ==========================================
	# MOVEMENT
	# ==========================================

	var joystick = (
		arduino_knight.get_movement()
	)

	var direction = Vector3.ZERO


	if joystick.length() > 0:

		direction.z = -joystick.y
		direction.x = -joystick.x

		direction = direction.normalized()

		direction = transform.basis * direction


	# ==========================================
	# JUMP
	# ==========================================

	if (
		Input.is_action_just_pressed("p2_jump")
		and is_on_floor()
		and not is_landing
		and not is_shielding
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

		if arduino_knight.sprint:

			velocity.x = direction.x * RUN_SPEED
			velocity.z = direction.z * RUN_SPEED


			if (
				not is_jumping
				and not is_landing
				and not is_shielding
				and not is_hit
			):

				if joystick.y < -0.15:

					play_animation(
						"Rig_Medium_MovementBasic/Running_B"
					)

				else:

					play_animation(
						"Rig_Medium_MovementAdvanced/Walking_Backwards"
					)


		else:

			velocity.x = direction.x * WALK_SPEED
			velocity.z = direction.z * WALK_SPEED


			if (
				not is_jumping
				and not is_landing
				and not is_shielding
				and not is_hit
			):

				if joystick.y < -0.15:

					play_animation(
						"Rig_Medium_MovementBasic/Walking_B"
					)

				else:

					play_animation(
						"Rig_Medium_MovementAdvanced/Walking_Backwards"
					)


	else:

		velocity.x = 0
		velocity.z = 0


		if (
			not is_jumping
			and not is_landing
			and not is_shielding
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

		var landing_length = (
			animation_player.current_animation_length
		)

		var landing_position = (
			animation_player.current_animation_position
		)


		if landing_position < landing_length - 0.08:

			return


		is_landing = false


		if direction.length() > 0:

			if arduino_knight.sprint:

				play_animation(
					"Rig_Medium_MovementBasic/Running_B"
				)

			else:

				if joystick.y >= 0.15:

					play_animation(
						"Rig_Medium_MovementAdvanced/Walking_Backwards"
					)

				else:

					play_animation(
						"Rig_Medium_MovementBasic/Walking_B"
					)


		else:

			play_animation(
				"Rig_Medium_General/Idle_A"
			)


# ==========================================
# ATTACK
# ==========================================

func attack():

	print(
		"Knight attacks!"
	)

	is_attacking = true


	if is_shielding:

		play_animation(
			"Rig_Medium_CombatMelee/Melee_Block_Attack"
		)

	else:

		play_animation(
			"Rig_Medium_CombatMelee/Melee_Unarmed_Attack_Punch_A"
		)


# ==========================================
# HEALTH / DAMAGE
# ==========================================

func take_damage(amount):

	if is_dead:

		return


	health -= amount


	print(
		"Player 2 health: ",
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
		is_attacking = false
		is_shielding = false
		shield_starting = false
		is_blocking_hit = false

		velocity = Vector3.ZERO

		play_animation(
			"Rig_Medium_General/Death_B"
		)

		print(
			"Player 2 defeated!"
		)

		return


	# ==========================================
	# NORMAL HIT
	# ==========================================

	is_hit = true

	play_animation(
		"Rig_Medium_General/Hit_A"
	)
