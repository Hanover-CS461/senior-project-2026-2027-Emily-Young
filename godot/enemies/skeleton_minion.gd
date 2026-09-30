extends CharacterBody3D


var health = 50
var speed = 2.0
var stop_distance = 0.5

var attack_damage = 10
var attack_cooldown = 1.5
var attack_timer = 0.0

var attack_windup = 1.0
var attack_timer_active = 0.0
var is_attacking = false

var attack_range = 0.7

var player1
var player2
var target_player

var animation_player
var current_animation = ""

var is_hit = false
var is_dying = false

var death_timer = 0.0
var death_wait_time = 3.0
var fade_time = 2.0

var skeleton_meshes = []

# Fight room
var fight_started = false
var is_awakening = false


func _ready():

	player1 = get_tree().get_first_node_in_group("player1")
	player2 = get_tree().get_first_node_in_group("player2")

	animation_player = $Skeleton_Minion/AnimationPlayer

	# Hide skeleton until a player enters the fight room
	$Skeleton_Minion.visible = false

	# Start with idle animation
	play_animation("Rig_Medium_General/Idle_A")

	# Find all skeleton meshes
	find_meshes($Skeleton_Minion)

	# Connect fight room
	$FightArea.body_entered.connect(_on_fight_area_body_entered)


func play_animation(animation_name: String):

	if current_animation != animation_name:

		animation_player.play(animation_name)

		current_animation = animation_name


func _physics_process(delta):

	# If neither player exists, do nothing
	if player1 == null and player2 == null:
		return


	# ============================================================
	# DEATH
	# ============================================================

	if is_dying:

		death_timer += delta

		if current_animation == "Rig_Medium_Special/Skeletons_Death":

			var death_length = animation_player.current_animation_length
			var death_position = animation_player.current_animation_position

			if death_position >= death_length:

				play_animation(
					"Rig_Medium_Special/Skeletons_Death_Pose"
				)

				death_timer = 0.0

			return


		if current_animation == "Rig_Medium_Special/Skeletons_Death_Pose":

			if death_timer < death_wait_time:
				return

			var fade_progress = (
				death_timer - death_wait_time
			) / fade_time

			fade_progress = clamp(
				fade_progress,
				0.0,
				1.0
			)

			set_fade(fade_progress)

			if fade_progress >= 1.0:

				queue_free()

			return


	# ============================================================
	# WAITING FOR PLAYER
	# ============================================================

	if not fight_started and not is_awakening:

		velocity.x = 0
		velocity.z = 0

		move_and_slide()

		return


	# ============================================================
	# AWAKENING
	# ============================================================

	if is_awakening:

		velocity.x = 0
		velocity.z = 0

		var awakening_length = (
			animation_player.current_animation_length
		)

		var awakening_position = (
			animation_player.current_animation_position
		)

		if awakening_position >= awakening_length:

			is_awakening = false
			fight_started = true

			play_animation(
				"Rig_Medium_General/Idle_A"
			)

			print("Skeleton awakened!")

		move_and_slide()

		return


	# ============================================================
	# HIT ANIMATION
	# ============================================================

	if is_hit:

		var hit_length = (
			animation_player.current_animation_length
		)

		var hit_position = (
			animation_player.current_animation_position
		)

		if hit_position >= hit_length:

			is_hit = false

		else:

			velocity.x = 0
			velocity.z = 0

			move_and_slide()

			return


	# ============================================================
	# TIMERS
	# ============================================================

	if attack_timer > 0:

		attack_timer -= delta


	if attack_timer_active > 0:

		attack_timer_active -= delta


	# ============================================================
	# FIND CLOSEST PLAYER
	# ============================================================

	target_player = get_closest_player()

	if target_player == null:
		return


	# ============================================================
	# ATTACKING
	# ============================================================

	if is_attacking:

		var attack_target = (
			target_player.global_position
		)

		attack_target.y = global_position.y

		look_at(
			attack_target,
			Vector3.UP
		)

		velocity.x = 0
		velocity.z = 0

		move_and_slide()


		if attack_timer_active <= 0:

			var distance = global_position.distance_to(
				target_player.global_position
			)


			if distance <= attack_range:

				if target_player.has_method("take_damage"):

					target_player.take_damage(
						attack_damage
					)

				print(
					"Skeleton hits ",
					target_player.name,
					"!"
				)

			else:

				print("Skeleton missed!")


			is_attacking = false
			attack_timer = attack_cooldown

		return


	# ============================================================
	# CHASING
	# ============================================================

	var target_position = (
		target_player.global_position
	)

	target_position.y = global_position.y

	var distance = global_position.distance_to(
		target_position
	)


	if distance > stop_distance:

		var direction = global_position.direction_to(
			target_position
		)

		direction.y = 0

		direction = direction.normalized()

		velocity.x = direction.x * speed
		velocity.z = direction.z * speed

		look_at(
			target_position,
			Vector3.UP
		)

		play_animation(
			"Rig_Medium_Special/Skeletons_Walking"
		)

		move_and_slide()

	else:

		velocity.x = 0
		velocity.z = 0

		move_and_slide()

		if attack_timer <= 0:

			attack()

		else:

			play_animation(
				"Rig_Medium_General/Idle_A"
			)


func get_closest_player():

	var closest_player = null
	var closest_distance = INF


	if player1 != null:

		var distance_to_player1 = (
			global_position.distance_to(
				player1.global_position
			)
		)

		if distance_to_player1 < closest_distance:

			closest_distance = distance_to_player1
			closest_player = player1


	if player2 != null:

		var distance_to_player2 = (
			global_position.distance_to(
				player2.global_position
			)
		)

		if distance_to_player2 < closest_distance:

			closest_distance = distance_to_player2
			closest_player = player2


	return closest_player


func attack():

	print(
		"Skeleton starts attacking ",
		target_player.name,
		"!"
	)

	is_attacking = true

	var attack_target = (
		target_player.global_position
	)

	attack_target.y = global_position.y

	look_at(
		attack_target,
		Vector3.UP
	)

	attack_timer_active = attack_windup

	play_animation(
		"Rig_Medium_CombatMelee/Melee_Unarmed_Attack_Punch_A"
	)


func take_damage(amount):

	if is_dying:
		return

	health -= amount

	print(
		"Minion health: ",
		health
	)


	if health > 0:

		is_hit = true
		is_attacking = false
		attack_timer_active = 0.0

		animation_player.stop()

		current_animation = ""

		animation_player.play(
			"Rig_Medium_General/Hit_B"
		)

		animation_player.seek(
			0.05,
			true
		)

		current_animation = (
			"Rig_Medium_General/Hit_B"
		)

	else:

		die()


func die():

	print("Skeleton died!")

	is_dying = true
	is_hit = false
	is_attacking = false

	death_timer = 0.0

	play_animation(
		"Rig_Medium_Special/Skeletons_Death"
	)


func find_meshes(node):

	for child in node.get_children():

		if child is MeshInstance3D:

			skeleton_meshes.append(child)

		if child.get_child_count() > 0:

			find_meshes(child)


func set_fade(amount):

	for mesh in skeleton_meshes:

		if mesh == null:
			continue

		var material = mesh.get_active_material(0)

		if material == null:
			continue


		if not material.resource_local_to_scene:

			material = material.duplicate()

			material.resource_local_to_scene = true

			mesh.set_surface_override_material(
				0,
				material
			)


		material.transparency = (
			BaseMaterial3D.TRANSPARENCY_ALPHA
		)

		material.albedo_color.a = (
			1.0 - amount
		)


func _on_fight_area_body_entered(body):

	if not body.is_in_group("player1") and not body.is_in_group("player2"):
		return


	if fight_started or is_awakening:
		return


	is_awakening = true

	# Make skeleton visible when fight begins
	$Skeleton_Minion.visible = true

	print("Skeleton awakening!")


	# Randomly choose one awakening animation
	var awakening_animations = [

		"Rig_Medium_Special/Skeletons_Awaken_Floor_Long",

		"Rig_Medium_Special/Skeletons_Spawn_Ground"

	]


	var chosen_animation = awakening_animations[
		randi() % awakening_animations.size()
	]


	play_animation(chosen_animation)
