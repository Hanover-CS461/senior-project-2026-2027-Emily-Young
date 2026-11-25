
extends CharacterBody3D

signal health_changed(current_health, maximum_health)
signal died(enemy)

# ============================================================
# STATS
# ============================================================

@export var spawn_visual_scale: float = 0.4
@export var gravity: float = 9.8

var health: float = 50.0
var max_health: float = 50.0

var speed: float = 2.0
var stop_distance: float = 0.5

var attack_damage: int = 10
var attack_cooldown: float = 1.5
var attack_timer: float = 0.0

var attack_windup: float = 1.0
var attack_timer_active: float = 0.0
var is_attacking: bool = false

var attack_range: float = 0.7

# ============================================================
# REFERENCES
# ============================================================

var player1
var player2
var target_player

var animation_player: AnimationPlayer
var visual_model: Node3D

var current_animation: String = ""

var is_hit: bool = false
var is_dying: bool = false

var death_timer: float = 0.0
var death_wait_time: float = 3.0
var fade_time: float = 2.0

var skeleton_meshes: Array[MeshInstance3D] = []

var fight_area: Area3D
var fight_started: bool = false
var is_awakening: bool = false

var visual_offset: Transform3D
var spawn_scale_applied: bool = false

var attack_animations: Array[String] = [
	"Rig_Medium_CombatMelee/Melee_Dualwield_Attack_Slice",
	"Rig_Medium_CombatMelee/Melee_Dualwield_Attack_Stab"
]


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	randomize()

	add_to_group("enemies")

	max_health = health

	player1 = get_tree().get_first_node_in_group("player1")
	player2 = get_tree().get_first_node_in_group("player2")

	visual_model = get_parent() as Node3D

	if visual_model == null:
		push_error("Skeleton Minion: Could not find Skeleton_Minion parent.")
		return

	print("Skeleton Minion visual model found: ", visual_model.get_path())

	animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer

	if animation_player == null:
		push_error("Skeleton Minion: No AnimationPlayer found beneath " + str(get_path()))
		return

	print("Skeleton Minion AnimationPlayer found: ", animation_player.get_path())

	visual_offset = global_transform.affine_inverse() * visual_model.global_transform

	visual_model.visible = false

	# Do not scale here.
	# Naturally placed Minions must remain full size.

	fight_area = find_child("FightArea", true, false) as Area3D

	if fight_area != null:
		if not fight_area.body_entered.is_connected(_on_fight_area_body_entered):
			fight_area.body_entered.connect(_on_fight_area_body_entered)
	else:
		print("Skeleton Minion: No local FightArea. Waiting for direct activation.")

	skeleton_meshes.clear()
	find_meshes(visual_model)

	print("Skeleton Minion meshes found: ", skeleton_meshes.size())

	play_animation("Rig_Medium_General/Idle_A")

	health_changed.emit(health, max_health)

	print("Skeleton Minion initialized successfully.")


# ============================================================
# SPAWN VISUAL SCALING
# ============================================================

func apply_spawn_scale() -> void:
	if spawn_scale_applied:
		return

	if not is_instance_valid(visual_model):
		return

	# Preserve the physics body's world transform.
	var original_body_transform: Transform3D = global_transform

	# Scale only the visual hierarchy.
	visual_model.scale *= spawn_visual_scale

	# Restore the physics body's world transform.
	global_transform = original_body_transform

	spawn_scale_applied = true

	print("Skeleton Minion spawn scale applied: ", spawn_visual_scale)


# ============================================================
# VISUAL / PHYSICS SYNCHRONIZATION
# ============================================================

func _process(_delta: float) -> void:
	if not is_instance_valid(visual_model):
		return

	var body_world_transform: Transform3D = global_transform
	var desired_visual_transform: Transform3D = body_world_transform * visual_offset

	visual_model.global_position = desired_visual_transform.origin

	# Correct the imported model's facing direction visually.
	visual_model.global_rotation = desired_visual_transform.basis.get_euler() + Vector3(0.0, PI, 0.0)

	# Keep the physics body at its original world transform.
	global_transform = body_world_transform


# ============================================================
# ANIMATION
# ============================================================

func play_animation(animation_name: String) -> void:
	if animation_player == null:
		return

	if not animation_player.has_animation(animation_name):
		push_warning("Minion animation not found: " + animation_name)
		return

	if current_animation != animation_name:
		animation_player.play(animation_name)
		current_animation = animation_name


# ============================================================
# MAIN LOOP
# ============================================================

func _physics_process(delta: float) -> void:
	if is_dying:
		process_death(delta)
		return

	if animation_player == null:
		return

	# GRAVITY
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Refresh player references.
	if not is_instance_valid(player1):
		player1 = get_tree().get_first_node_in_group("player1")

	if not is_instance_valid(player2):
		player2 = get_tree().get_first_node_in_group("player2")

	if player1 == null and player2 == null:
		move_and_slide()
		return

	# Wait until summoned.
	if not fight_started and not is_awakening:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# Awakening animation.
	if is_awakening:
		velocity.x = 0.0
		velocity.z = 0.0

		var awakening_length = animation_player.current_animation_length
		var awakening_position = animation_player.current_animation_position

		if awakening_position >= awakening_length or not animation_player.is_playing():
			is_awakening = false
			fight_started = true
			play_animation("Rig_Medium_General/Idle_A")
			print("Skeleton Minion awakened and entering combat!")

		move_and_slide()
		return

	# Hit reaction.
	if is_hit:
		var hit_length = animation_player.current_animation_length
		var hit_position = animation_player.current_animation_position

		if hit_position >= hit_length or not animation_player.is_playing():
			is_hit = false
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			move_and_slide()
			return

	if attack_timer > 0.0:
		attack_timer -= delta

	if attack_timer_active > 0.0:
		attack_timer_active -= delta

	target_player = get_closest_player()

	if target_player == null:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# Attack windup and damage.
	if is_attacking:
		if is_player_dead(target_player):
			is_attacking = false
			attack_timer_active = 0.0
			play_animation("Rig_Medium_General/Idle_A")
			return

		var attack_target = target_player.global_position
		attack_target.y = global_position.y

		look_at(attack_target, Vector3.UP)

		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()

		if attack_timer_active <= 0.0:
			var distance = global_position.distance_to(target_player.global_position)

			if distance <= attack_range and not is_player_dead(target_player):
				if target_player.has_method("take_damage"):
					target_player.take_damage(attack_damage)

				print("Skeleton Minion hits ", target_player.name, "!")
			else:
				print("Skeleton Minion missed!")

			is_attacking = false
			attack_timer = attack_cooldown
			play_animation("Rig_Medium_General/Idle_A")

		return

	# Chase target.
	var target_position = target_player.global_position
	target_position.y = global_position.y

	var distance = global_position.distance_to(target_position)

	if distance > stop_distance:
		var direction = global_position.direction_to(target_position)
		direction.y = 0.0
		direction = direction.normalized()

		velocity.x = direction.x * speed
		velocity.z = direction.z * speed

		look_at(target_position, Vector3.UP)
		play_animation("Rig_Medium_Special/Skeletons_Walking")
		move_and_slide()
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()

		if attack_timer <= 0.0:
			attack()
		else:
			play_animation("Rig_Medium_General/Idle_A")


# ============================================================
# PLAYER TARGETING
# ============================================================

func is_player_dead(player: Node) -> bool:
	if not is_instance_valid(player):
		return true

	if player.get("is_dead") == true:
		return true

	if player.get("is_alive") == false:
		return true

	return false


func get_closest_player():
	var closest_player = null
	var closest_distance = INF

	if is_instance_valid(player1) and not is_player_dead(player1):
		var distance_to_player1 = global_position.distance_to(player1.global_position)

		if distance_to_player1 < closest_distance:
			closest_distance = distance_to_player1
			closest_player = player1

	if is_instance_valid(player2) and not is_player_dead(player2):
		var distance_to_player2 = global_position.distance_to(player2.global_position)

		if distance_to_player2 < closest_distance:
			closest_distance = distance_to_player2
			closest_player = player2

	return closest_player


# ============================================================
# ATTACKING
# ============================================================

func attack() -> void:
	if not is_instance_valid(target_player):
		return

	if is_player_dead(target_player):
		return

	print("Skeleton Minion starts attacking ", target_player.name, "!")

	is_attacking = true

	var attack_target = target_player.global_position
	attack_target.y = global_position.y

	look_at(attack_target, Vector3.UP)

	attack_timer_active = attack_windup

	var chosen_attack = attack_animations[randi() % attack_animations.size()]
	play_animation(chosen_attack)


# ============================================================
# DAMAGE
# ============================================================

func take_damage(amount: float) -> void:
	if is_dying or amount <= 0.0:
		return

	health -= amount
	health = maxf(health, 0.0)

	health_changed.emit(health, max_health)

	print("Minion health: ", health, "/", max_health)

	if health > 0.0:
		is_hit = true
		is_attacking = false
		attack_timer_active = 0.0

		animation_player.stop()
		current_animation = ""

		if animation_player.has_animation("Rig_Medium_General/Hit_B"):
			animation_player.play("Rig_Medium_General/Hit_B")
			animation_player.seek(0.05, true)
			current_animation = "Rig_Medium_General/Hit_B"
	else:
		die()


# ============================================================
# DEATH
# ============================================================

func die() -> void:
	if is_dying:
		return

	print("Skeleton Minion died!")

	is_dying = true
	died.emit(self)

	is_hit = false
	is_attacking = false
	fight_started = false
	is_awakening = false

	velocity = Vector3.ZERO
	death_timer = 0.0

	if is_instance_valid(fight_area):
		fight_area.set_deferred("monitoring", false)

	play_animation("Rig_Medium_Special/Skeletons_Death")


func process_death(delta: float) -> void:
	death_timer += delta

	if animation_player == null:
		remove_minion_visual()
		return

	if current_animation == "Rig_Medium_Special/Skeletons_Death":
		var death_length = animation_player.current_animation_length
		var death_position = animation_player.current_animation_position

		if death_position >= death_length or not animation_player.is_playing():
			play_animation("Rig_Medium_Special/Skeletons_Death_Pose")
			death_timer = 0.0

		return

	if current_animation == "Rig_Medium_Special/Skeletons_Death_Pose":
		if death_timer < death_wait_time:
			return

		var fade_progress = (death_timer - death_wait_time) / maxf(fade_time, 0.001)
		fade_progress = clampf(fade_progress, 0.0, 1.0)

		set_fade(fade_progress)

		if fade_progress >= 1.0:
			remove_minion_visual()


func remove_minion_visual() -> void:
	if is_instance_valid(visual_model):
		visual_model.queue_free()
	else:
		queue_free()


# ============================================================
# MESH / FADE
# ============================================================

func find_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			skeleton_meshes.append(child)

		if child.get_child_count() > 0:
			find_meshes(child)


func set_fade(amount: float) -> void:
	for mesh in skeleton_meshes:
		if not is_instance_valid(mesh) or mesh.mesh == null:
			continue

		for surface in range(mesh.mesh.get_surface_count()):
			var material = mesh.get_active_material(surface)

			if material == null:
				continue

			if not material.resource_local_to_scene:
				material = material.duplicate()
				material.resource_local_to_scene = true
				mesh.set_surface_override_material(surface, material)

			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

			var color = material.albedo_color
			color.a = 1.0 - amount
			material.albedo_color = color


# ============================================================
# ACTIVATION
# ============================================================

func activate() -> void:
	if fight_started or is_awakening or is_dying:
		return

	if animation_player == null or visual_model == null:
		push_error("Skeleton Minion cannot activate: visual model or AnimationPlayer is missing.")
		return

	# Only Mage-summoned Minions receive this scale.
	apply_spawn_scale()

	is_awakening = true
	visual_model.visible = true

	print("Skeleton Minion summoned at visual scale: ", spawn_visual_scale)

	var awakening_animations = [
		"Rig_Medium_Special/Skeletons_Awaken_Floor_Long",
		"Rig_Medium_Special/Skeletons_Spawn_Ground"
	]

	var available_animations: Array[String] = []

	for animation_name in awakening_animations:
		if animation_player.has_animation(animation_name):
			available_animations.append(animation_name)

	if available_animations.is_empty():
		is_awakening = false
		fight_started = true
		play_animation("Rig_Medium_General/Idle_A")
		print("Skeleton Minion: No awakening animation found; entering combat.")
		return

	play_animation(available_animations.pick_random())


func wake_up() -> void:
	activate()


func _on_fight_area_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player1") and not body.is_in_group("player2"):
		return

	activate()
