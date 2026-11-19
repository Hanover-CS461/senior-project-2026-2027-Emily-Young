
extends CharacterBody3D

signal health_changed(current_health, maximum_health)
signal died(enemy)

# ==================================================
# SETTINGS
# ==================================================

@export var health: float = 180.0
@export var speed: float = 1.2

@export var attack_damage: float = 30.0
@export var attack_cooldown: float = 2.5
@export var attack_windup: float = 1.3
@export var attack_range: float = 1.2

# Temporarily disabled while testing projectile collisions.
@export_range(0.0, 1.0) var shield_damage_reduction: float = 0.0
@export var flinch_threshold: float = 25.0

@export var death_wait_time: float = 3.0
@export var fade_time: float = 2.0

# ==================================================
# ANIMATIONS
# ==================================================

var anim_idle := "Rig_Medium_General/Idle_A"
var anim_walk := "Rig_Medium_Special/Skeletons_Walking"
var anim_hit := "Rig_Medium_General/Hit_B"

var anim_death := "Rig_Medium_Special/Skeletons_Death"
var anim_death_pose := "Rig_Medium_Special/Skeletons_Death_Pose"
var anim_spawn := "Rig_Medium_Special/Skeletons_Spawn_Ground"

var shield_raise_animation := "Rig_Medium_CombatMelee/Melee_Block"
var shield_hold_animation := "Rig_Medium_CombatMelee/Melee_Blocking"
var shield_attack_animation := "Rig_Medium_CombatMelee/Melee_Block_Attack"
var shield_hit_animation := "Rig_Medium_CombatMelee/Melee_Block_Hit"

var anim_attack_options: Array[String] = [
	"Rig_Medium_CombatMelee/Melee_1H_Attack_Chop",
	"Rig_Medium_CombatMelee/Melee_1H_Attack_Jump_Chop",
	"Rig_Medium_CombatMelee/Melee_2H_Attack_Spin"
]

# ==================================================
# REFERENCES
# ==================================================

var visual_model: Node3D
var animation_player: AnimationPlayer
var fight_area: Area3D

# ==================================================
# STATE
# ==================================================

var max_health: float

var is_alive := true
var is_awake := false
var is_waking := false

var is_attacking := false
var is_guarding := false
var is_shield_hit := false
var is_flinching := false

var can_attack := true
var attack_damage_applied := false

var attack_elapsed := 0.0
var attack_animation_length := 0.0
var attack_cooldown_timer := 0.0

var shield_hit_timer := 0.0
var flinch_timer := 0.0

var current_target: Node3D


# ==================================================
# READY
# ==================================================

func _ready() -> void:
	max_health = health

	# Register the actual CharacterBody3D as an enemy.
	if not is_in_group("enemies"):
		add_to_group("enemies")

	var rig := get_parent()

	if rig == null or rig.get_parent() == null:
		push_error("Skeleton Bruiser: Unexpected scene hierarchy.")
		return

	var scene_root := rig.get_parent()

	visual_model = scene_root as Node3D
	animation_player = scene_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	fight_area = scene_root.get_node_or_null("FightArea") as Area3D

	if visual_model == null:
		push_error("Skeleton Bruiser: Could not find Skeleton_Warrior.")
		return

	if animation_player == null:
		push_error("Skeleton Bruiser: Could not find AnimationPlayer.")
		return

	if fight_area == null:
		push_error("Skeleton Bruiser: Could not find FightArea.")
		return

	if not fight_area.body_entered.is_connected(_on_fight_area_body_entered):
		fight_area.body_entered.connect(_on_fight_area_body_entered)

	visual_model.visible = false

	is_awake = false
	is_waking = false
	is_guarding = false

	health_changed.emit(health, max_health)

	print("Skeleton Bruiser initialized. Waiting for player.")
	print("Skeleton Bruiser registered in enemies group.")


# ==================================================
# FIGHT AREA / ACTIVATION
# ==================================================

func _on_fight_area_body_entered(body: Node3D) -> void:
	if not is_alive or is_awake or is_waking:
		return

	if not is_player(body):
		return

	current_target = body
	start_wake_up()


func is_player(body: Node) -> bool:
	if body == null:
		return false

	return body.is_in_group("player1") or body.is_in_group("player2")


func start_wake_up() -> void:
	if not is_alive or is_awake or is_waking:
		return

	is_waking = true
	is_guarding = false

	visual_model.visible = true
	velocity = Vector3.ZERO

	print("Skeleton Bruiser: Player detected. Spawning.")

	if animation_player.has_animation(anim_spawn):
		play_animation(anim_spawn)

		var spawn_length := get_animation_length(anim_spawn)

		if spawn_length > 0.0:
			await get_tree().create_timer(spawn_length).timeout
	else:
		push_warning("Skeleton Bruiser: Spawn animation not found.")
		await get_tree().create_timer(0.5).timeout

	if not is_alive or not is_instance_valid(visual_model):
		return

	is_waking = false
	is_awake = true
	is_guarding = true

	if animation_player.has_animation(shield_raise_animation):
		play_animation(shield_raise_animation)

		var raise_length := get_animation_length(shield_raise_animation)

		if raise_length > 0.0:
			await get_tree().create_timer(raise_length).timeout

	if not is_alive:
		return

	raise_shield()

	print("Skeleton Bruiser: Combat activated.")


# ==================================================
# PHYSICS
# ==================================================

func _physics_process(delta: float) -> void:
	if not is_alive or not is_awake or is_waking:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

		if attack_cooldown_timer <= 0.0:
			can_attack = true

	if shield_hit_timer > 0.0:
		shield_hit_timer -= delta

		if shield_hit_timer <= 0.0:
			is_shield_hit = false
			raise_shield()

	if flinch_timer > 0.0:
		flinch_timer -= delta

		if flinch_timer <= 0.0:
			is_flinching = false
			raise_shield()

	if is_flinching or is_shield_hit:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide_synced()
		return

	if is_attacking:
		process_attack(delta)
		move_and_slide_synced()
		return

	process_combat_movement()
	move_and_slide_synced()


# ==================================================
# SYNCHRONIZED MOVEMENT
# ==================================================

func move_and_slide_synced() -> void:
	if not is_instance_valid(visual_model):
		move_and_slide()
		return

	var body_position_before := global_position

	move_and_slide()

	var movement := global_position - body_position_before

	visual_model.global_position += movement
	global_position -= movement


# ==================================================
# PLAYER DETECTION
# ==================================================

func get_closest_player() -> Node3D:
	var closest_player: Node3D = null
	var closest_distance := INF

	var players: Array[Node] = []
	players.append_array(get_tree().get_nodes_in_group("player1"))
	players.append_array(get_tree().get_nodes_in_group("player2"))

	for player in players:
		if not is_instance_valid(player):
			continue

		if not player is Node3D:
			continue

		if player.get("is_dead") == true:
			continue

		var player_node := player as Node3D
		var distance := get_flat_distance(global_position, player_node.global_position)

		if distance < closest_distance:
			closest_distance = distance
			closest_player = player_node

	return closest_player


func get_flat_distance(first: Vector3, second: Vector3) -> float:
	first.y = 0.0
	second.y = 0.0
	return first.distance_to(second)


# ==================================================
# MOVEMENT / COMBAT
# ==================================================

func process_combat_movement() -> void:
	current_target = get_closest_player()

	if current_target == null:
		velocity.x = 0.0
		velocity.z = 0.0
		raise_shield()
		return

	var distance := get_flat_distance(global_position, current_target.global_position)

	face_player(current_target)

	if distance > attack_range:
		var direction := current_target.global_position - global_position
		direction.y = 0.0
		direction = direction.normalized()

		velocity.x = direction.x * speed
		velocity.z = direction.z * speed

		is_guarding = true

		if animation_player.current_animation != anim_walk:
			play_animation(anim_walk)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

		if can_attack:
			start_attack()
		else:
			raise_shield()


func face_player(player: Node3D) -> void:
	if player == null or not is_instance_valid(visual_model):
		return

	var direction := player.global_position - visual_model.global_position
	direction.y = 0.0

	if direction.length_squared() > 0.001:
		visual_model.look_at(
			visual_model.global_position + direction,
			Vector3.UP
		)

		# Fixed imported-model orientation correction.
		visual_model.rotate_y(PI)


# ==================================================
# SHIELD
# ==================================================

func raise_shield() -> void:
	if not is_alive or not is_awake:
		return

	if is_attacking or is_shield_hit or is_flinching:
		return

	is_guarding = true
	play_animation(shield_hold_animation)


func lower_shield() -> void:
	is_guarding = false


func play_shield_hit() -> void:
	if not is_alive:
		return

	is_shield_hit = true
	shield_hit_timer = get_animation_length(shield_hit_animation)

	if shield_hit_timer <= 0.0:
		shield_hit_timer = 0.5

	play_animation(shield_hit_animation)


# ==================================================
# ATTACKING
# ==================================================

func start_attack() -> void:
	if not is_alive or is_attacking or not can_attack:
		return

	is_attacking = true
	can_attack = false
	attack_damage_applied = false
	attack_elapsed = 0.0

	lower_shield()

	velocity.x = 0.0
	velocity.z = 0.0

	var available_attacks: Array[String] = []

	for animation_name in anim_attack_options:
		if animation_player.has_animation(animation_name):
			available_attacks.append(animation_name)

	if available_attacks.is_empty():
		push_warning("Skeleton Bruiser: No axe attack animations found.")
		finish_attack()
		return

	var selected_attack: String = available_attacks.pick_random()

	attack_animation_length = get_animation_length(selected_attack)

	if attack_animation_length <= 0.0:
		attack_animation_length = attack_windup + 0.5

	play_animation(selected_attack)


func process_attack(delta: float) -> void:
	attack_elapsed += delta

	if not attack_damage_applied and attack_elapsed >= attack_windup:
		attack_damage_applied = true
		perform_attack_damage()

	if attack_elapsed >= maxf(attack_animation_length, attack_windup):
		finish_attack()


func perform_attack_damage() -> void:
	current_target = get_closest_player()

	if current_target == null:
		return

	var distance := get_flat_distance(
		global_position,
		current_target.global_position
	)

	if distance > attack_range:
		return

	if current_target.has_method("take_damage"):
		current_target.take_damage(attack_damage)


func finish_attack() -> void:
	is_attacking = false
	attack_elapsed = 0.0
	attack_damage_applied = false

	attack_cooldown_timer = attack_cooldown

	if is_alive:
		raise_shield()


# ==================================================
# DAMAGE
# ==================================================

func take_damage(amount: float) -> void:
	print("--------------------------------")
	print("BRUISER HIT DETECTED")
	print("Incoming damage: ", amount)

	if not is_alive or amount <= 0.0:
		return

	var damage_received := amount

	if is_guarding and not is_attacking:
		damage_received *= (1.0 - shield_damage_reduction)
		print("Shield reduced damage to: ", damage_received)

	health = maxf(0.0, health - damage_received)
	health_changed.emit(health, max_health)

	print("Bruiser remaining health: ", health)

	if health <= 0.0:
		die()
		return

	if is_guarding and not is_attacking:
		play_shield_hit()
	elif damage_received >= flinch_threshold:
		flinch()
	else:
		play_animation(anim_hit)


func flinch() -> void:
	if not is_alive or is_flinching:
		return

	is_flinching = true
	is_guarding = false

	flinch_timer = get_animation_length(anim_hit)

	if flinch_timer <= 0.0:
		flinch_timer = 0.6

	play_animation(anim_hit)


# ==================================================
# ACTIVATION COMPATIBILITY
# ==================================================

func activate() -> void:
	start_wake_up()


func wake_up() -> void:
	start_wake_up()


# ==================================================
# ANIMATION HELPERS
# ==================================================

func play_animation(animation_name: String) -> void:
	if animation_player == null:
		return

	if not animation_player.has_animation(animation_name):
		push_warning("Skeleton Bruiser: Missing animation: " + animation_name)
		return

	if animation_player.current_animation == animation_name:
		return

	animation_player.play(animation_name)


func get_animation_length(animation_name: String) -> float:
	if animation_player == null:
		return 0.0

	if not animation_player.has_animation(animation_name):
		return 0.0

	return animation_player.get_animation(animation_name).length


# ==================================================
# DEATH
# ==================================================

func die() -> void:
	if not is_alive:
		return

	is_alive = false
	is_awake = false
	is_waking = false
	is_attacking = false
	is_guarding = false

	velocity = Vector3.ZERO

	if is_instance_valid(fight_area):
		fight_area.set_deferred("monitoring", false)

	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)

	died.emit(self)

	if animation_player.has_animation(anim_death):
		play_animation(anim_death)
		await get_tree().create_timer(get_animation_length(anim_death)).timeout
	elif animation_player.has_animation(anim_death_pose):
		play_animation(anim_death_pose)
		await get_tree().create_timer(get_animation_length(anim_death_pose)).timeout

	await get_tree().create_timer(death_wait_time).timeout

	if is_instance_valid(visual_model):
		await fade_out()


# ==================================================
# FADE OUT
# ==================================================

func fade_out() -> void:
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(visual_model, meshes)

	for mesh_instance in meshes:
		if mesh_instance.mesh == null:
			continue

		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(surface_index)

			if material == null:
				continue

			var new_material := material.duplicate() as StandardMaterial3D

			if new_material == null:
				continue

			mesh_instance.set_surface_override_material(surface_index, new_material)
			new_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

			var tween := create_tween()
			tween.tween_property(
				new_material,
				"albedo_color:a",
				0.0,
				fade_time
			)

	await get_tree().create_timer(fade_time).timeout

	if is_instance_valid(visual_model):
		visual_model.queue_free()


func _find_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)

	for child in node.get_children():
		_find_meshes(child, result)
