extends CharacterBody3D

var health = 50
var speed = 2.0
var stop_distance = 0.5

var attack_damage = 10
var attack_cooldown = 1.5
var attack_timer = 0.0

var attack_windup = 1
var attack_timer_active = 0.0
var is_attacking = false

var attack_range = 0.7

var player2
var animation_player
var current_animation = ""

var is_hit = false
var is_dying = false

var death_timer = 0.0
var death_wait_time = 3.0
var fade_time = 2.0

var skeleton_meshes = []


func _ready():

	player2 = get_tree().get_first_node_in_group("player2")

	animation_player = $Skeleton_Minion/AnimationPlayer

	play_animation("Rig_Medium_General/Idle_A")

	# Find all of the skeleton's meshes
	find_meshes($Skeleton_Minion)


func play_animation(animation_name: String):

	if current_animation != animation_name:

		animation_player.play(animation_name)

		current_animation = animation_name


func _physics_process(delta):

	if player2 == null:
		return


	# --------------------------------------------------
	# DEATH
	# --------------------------------------------------

	if is_dying:

		death_timer += delta

		# Wait for Death_B animation to finish
		if current_animation == "Rig_Medium_General/Death_B":

			var death_length = animation_player.current_animation_length
			var death_position = animation_player.current_animation_position

			if death_position >= death_length:

				play_animation("Rig_Medium_General/Death_B_Pose")

				death_timer = 0.0

			return


		# Stay in the death pose for a few seconds
		if current_animation == "Rig_Medium_General/Death_B_Pose":

			if death_timer < death_wait_time:
				return

			# Start fading
			var fade_progress = (death_timer - death_wait_time) / fade_time

			fade_progress = clamp(fade_progress, 0.0, 1.0)

			set_fade(fade_progress)

			if fade_progress >= 1.0:
				queue_free()

			return


	# --------------------------------------------------
	# HIT
	# --------------------------------------------------

	if is_hit:

		var hit_length = animation_player.current_animation_length
		var hit_position = animation_player.current_animation_position

		# Wait until Hit_B finishes
		if hit_position >= hit_length:

			is_hit = false

		else:

			return


	# --------------------------------------------------
	# ATTACK TIMERS
	# --------------------------------------------------

	if attack_timer > 0:
		attack_timer -= delta

	if attack_timer_active > 0:
		attack_timer_active -= delta


	# --------------------------------------------------
	# CURRENT ATTACK
	# --------------------------------------------------

	if is_attacking:

		var attack_target = player2.global_position

		attack_target.y = global_position.y

		look_at(attack_target, Vector3.UP)

		if attack_timer_active <= 0:

			var distance = global_position.distance_to(
				player2.global_position
			)

			if distance <= attack_range:

				if player2.has_method("take_damage"):
					player2.take_damage(attack_damage)

				print("Skeleton hits Player 2!")

			else:

				print("Skeleton missed!")

			is_attacking = false
			attack_timer = attack_cooldown

		return


	# --------------------------------------------------
	# GET PLAYER 2 POSITION
	# --------------------------------------------------

	var target_position = player2.global_position

	target_position.y = global_position.y

	var distance = global_position.distance_to(target_position)


	# --------------------------------------------------
	# CHASE PLAYER 2
	# --------------------------------------------------

	if distance > stop_distance:

		global_position = global_position.move_toward(
			target_position,
			speed * delta
		)

		play_animation("Rig_Medium_MovementBasic/Walking_A")


	# --------------------------------------------------
	# ATTACK PLAYER 2
	# --------------------------------------------------

	else:

		velocity = Vector3.ZERO

		if attack_timer <= 0:

			attack()

		else:

			play_animation("Rig_Medium_General/Idle_A")


# --------------------------------------------------
# ATTACK
# --------------------------------------------------

func attack():

	print("Skeleton starts attacking!")

	is_attacking = true

	var attack_target = player2.global_position

	attack_target.y = global_position.y

	look_at(attack_target, Vector3.UP)

	attack_timer_active = attack_windup

	play_animation("Rig_Medium_General/Throw")


# --------------------------------------------------
# HEALTH / DAMAGE
# --------------------------------------------------

func take_damage(amount):

	if is_dying:
		return

	health -= amount

	print("Minion health: ", health)

	if health > 0:

		is_hit = true

		is_attacking = false

		attack_timer_active = 0.0

		# Immediately stop the current animation
		animation_player.stop()

		current_animation = ""

		# Start the hit animation immediately
		animation_player.play("Rig_Medium_General/Hit_B")

		# Skip the tiny beginning of the animation
		animation_player.seek(0.05, true)

		current_animation = "Rig_Medium_General/Hit_B"

	else:

		die()


# --------------------------------------------------
# DEATH
# --------------------------------------------------

func die():

	print("Skeleton died!")

	is_dying = true

	is_hit = false

	is_attacking = false

	death_timer = 0.0

	play_animation("Rig_Medium_General/Death_B")


# --------------------------------------------------
# FIND SKELETON MESHES
# --------------------------------------------------

func find_meshes(node):

	for child in node.get_children():

		if child is MeshInstance3D:

			skeleton_meshes.append(child)

		if child.get_child_count() > 0:

			find_meshes(child)


# --------------------------------------------------
# FADE OUT
# --------------------------------------------------

func set_fade(amount):

	for mesh in skeleton_meshes:

		if mesh == null:
			continue

		var material = mesh.get_active_material(0)

		if material == null:
			continue

		# Make a unique copy of the material
		if not material.resource_local_to_scene:

			material = material.duplicate()

			material.resource_local_to_scene = true

			mesh.set_surface_override_material(
				0,
				material
			)

		# Enable transparency
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

		# Fade the skeleton out
		material.albedo_color.a = 1.0 - amount
