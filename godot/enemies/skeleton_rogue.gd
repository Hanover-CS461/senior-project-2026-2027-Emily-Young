
extends CharacterBody3D

signal health_changed(current, maximum)
signal died(enemy)

@export var health: float = 100.0
@export var speed: float = 3.6
@export var stop_distance: float = 0.5

@export var attack_damage: float = 8.0
@export var attack_range: float = 1.2
@export var attack_cooldown: float = 0.8
@export var attack_windup: float = 0.45

@export var flinch_threshold: float = 1.0
@export var death_wait_time: float = 3.0
@export var fade_time: float = 2.0

const MODEL_Y_ROTATION_OFFSET: float = PI

var current_health: float
var is_dead: bool = false
var is_attacking: bool = false
var can_attack: bool = true
var is_awake: bool = false
var is_waking: bool = false
var is_flinching: bool = false

var target_player: Node3D = null

var model: Node3D
var visual_model: Node3D

var animation_player: AnimationPlayer
var fight_area: Area3D

var original_body_transform: Transform3D

var visual_meshes: Array[MeshInstance3D] = []

var idle_animation: String = "Rig_Medium_General/Idle_A"
var walk_animation: String = "Rig_Medium_Special/Skeletons_Walking"
var hit_animation: String = "Rig_Medium_General/Hit_B"
var death_animation: String = "Rig_Medium_Special/Skeletons_Death"
var death_pose_animation: String = "Rig_Medium_Special/Skeletons_Death_Pose"
var spawn_animation: String = "Rig_Medium_Special/Skeletons_Spawn_Ground"

var attack_animations: Array[String] = [
	"Rig_Medium_CombatMelee/Melee_Dualwield_Attack_Slice",
	"Rig_Medium_CombatMelee/Melee_Dualwield_Attack_Stab",
	"Rig_Medium_CombatMelee/Melee_1H_Attack_Stab"
]


func _ready() -> void:
	current_health = health

	# Register this rogue in both groups.
	add_to_group("enemies")
	add_to_group("rogue_room")

	model = get_parent() as Node3D

	if model == null:
		push_error("Skeleton Rogue: Could not find enemy root.")
		return

	visual_model = model.get_node_or_null("Rig_Medium") as Node3D

	if visual_model == null:
		push_error(
			"Skeleton Rogue: Could not find Rig_Medium under enemy root."
		)
		return

	model.visible = false

	original_body_transform = transform

	animation_player = model.find_child(
		"AnimationPlayer",
		true,
		false
	) as AnimationPlayer

	if animation_player == null:
		push_error("Skeleton Rogue: AnimationPlayer not found.")
		return

	find_visual_meshes(visual_model)

	var search_node: Node = self

	while search_node != null:
		fight_area = search_node.get_node_or_null("FightArea") as Area3D

		if fight_area != null:
			break

		search_node = search_node.get_parent()

	if fight_area != null:
		fight_area.body_entered.connect(_on_fight_area_body_entered)
	else:
		push_warning("Skeleton Rogue: FightArea was not found.")

	velocity = Vector3.ZERO
	health_changed.emit(current_health, health)

	print("Skeleton Rogue ready. Registered in enemies and rogue_room groups.")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_awake or is_waking:
		return

	if is_flinching:
		return

	if is_attacking:
		velocity.x = 0.0
		velocity.z = 0.0
		move_body_and_sync()
		return

	find_nearest_player()

	if target_player == null:
		velocity.x = 0.0
		velocity.z = 0.0
		play_animation(idle_animation)
		move_body_and_sync()
		return

	var direction: Vector3 = (
		target_player.global_position - global_position
	)

	direction.y = 0.0

	var distance: float = direction.length()

	if distance > 0.01:
		direction = direction.normalized()
		face_player()

	if distance > stop_distance:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		play_animation(walk_animation)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		play_animation(idle_animation)

		if can_attack:
			start_attack()

	move_body_and_sync()


func move_body_and_sync() -> void:
	if is_dead:
		return

	move_and_slide()

	if model != null:
		model.global_transform = (
			global_transform
			* original_body_transform.affine_inverse()
		)

		transform = original_body_transform


func face_player() -> void:
	if target_player == null:
		return

	var look_position: Vector3 = target_player.global_position
	look_position.y = global_position.y

	if global_position.distance_to(look_position) < 0.01:
		return

	look_at(look_position, Vector3.UP)
	rotate_y(MODEL_Y_ROTATION_OFFSET)


func find_nearest_player() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player1")
	players.append_array(get_tree().get_nodes_in_group("player2"))

	var nearest_distance: float = INF
	target_player = null

	for player in players:
		if not is_instance_valid(player):
			continue

		if not player is Node3D:
			continue

		if player.get("is_dead") == true:
			continue

		var player_node: Node3D = player as Node3D

		var distance: float = global_position.distance_to(
			player_node.global_position
		)

		if distance < nearest_distance:
			nearest_distance = distance
			target_player = player_node


func start_attack() -> void:
	if not can_attack or is_attacking or is_dead:
		return

	if not is_instance_valid(target_player):
		return

	can_attack = false
	is_attacking = true

	velocity.x = 0.0
	velocity.z = 0.0

	face_player()

	var chosen_attack: String = attack_animations[
		randi_range(0, attack_animations.size() - 1)
	]

	if not animation_player.has_animation(chosen_attack):
		push_warning(
			"Skeleton Rogue: Missing attack animation: "
			+ chosen_attack
		)

		is_attacking = false
		can_attack = true
		return

	var attack_duration: float = (
		animation_player.get_animation(chosen_attack).length
	)

	play_animation(chosen_attack)

	await get_tree().create_timer(attack_windup).timeout

	if is_dead:
		return

	resolve_attack_hit()

	if is_dead:
		return

	var remaining_time: float = maxf(
		attack_duration - attack_windup,
		0.0
	)

	if remaining_time > 0.0:
		await get_tree().create_timer(remaining_time).timeout

	if is_dead:
		return

	is_attacking = false

	await get_tree().create_timer(attack_cooldown).timeout

	if not is_dead:
		can_attack = true


func resolve_attack_hit() -> void:
	if is_dead:
		return

	find_nearest_player()

	if not is_instance_valid(target_player):
		print("Skeleton Rogue attack missed: no player found.")
		return

	if target_player.get("is_dead") == true:
		print("Skeleton Rogue attack missed: target is defeated.")
		return

	var distance: float = global_position.distance_to(
		target_player.global_position
	)

	if distance > attack_range:
		print(
			"Skeleton Rogue attack missed. Distance: ",
			distance,
			" | Range: ",
			attack_range
		)
		return

	if not target_player.has_method("take_damage"):
		push_warning(
			"Skeleton Rogue: Target has no take_damage() function: "
			+ str(target_player.get_path())
		)
		return

	target_player.call("take_damage", int(attack_damage))

	print(
		"Skeleton Rogue hit ",
		target_player.name,
		" for ",
		attack_damage,
		" damage."
	)


func _on_fight_area_body_entered(body: Node3D) -> void:
	if is_dead:
		return

	if (
		body.is_in_group("player1")
		or body.is_in_group("player2")
	):
		wake_up()


func wake_up() -> void:
	if is_awake or is_dead:
		return

	is_awake = true
	is_waking = true

	model.visible = true

	if animation_player.has_animation(spawn_animation):
		var spawn_duration: float = (
			animation_player.get_animation(spawn_animation).length
		)

		play_animation(spawn_animation)

		await get_tree().create_timer(spawn_duration).timeout
	else:
		play_animation(idle_animation)

	if is_dead:
		return

	is_waking = false


func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return

	current_health -= amount
	current_health = maxf(current_health, 0.0)

	health_changed.emit(current_health, health)

	print(
		"Skeleton Rogue health: ",
		current_health,
		"/",
		health
	)

	if current_health <= 0.0:
		die()
		return

	if flinch_threshold > 0.0 and amount >= flinch_threshold:
		flinch()


func flinch() -> void:
	if is_dead or is_flinching:
		return

	is_flinching = true
	is_attacking = false

	velocity = Vector3.ZERO

	if animation_player.has_animation(hit_animation):
		var hit_duration: float = (
			animation_player.get_animation(hit_animation).length
		)

		play_animation(hit_animation)

		await get_tree().create_timer(hit_duration).timeout

	if is_dead:
		return

	is_flinching = false


func die() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	is_flinching = false
	is_waking = false

	velocity = Vector3.ZERO

	# Remove the rogue from the exit's enemy-counting group immediately.
	remove_from_group("rogue_room")

	print(
		"Skeleton Rogue defeated! Remaining rogues: ",
		get_tree().get_nodes_in_group("rogue_room").size()
	)

	if fight_area != null:
		fight_area.monitoring = false

	died.emit(self)

	if animation_player.has_animation(death_animation):
		play_animation(death_animation)

		await get_tree().create_timer(
			animation_player.get_animation(death_animation).length
		).timeout

	if is_instance_valid(self):
		await fade_out()


func find_visual_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			visual_meshes.append(child)

		if child.get_child_count() > 0:
			find_visual_meshes(child)


func fade_out() -> void:
	if visual_meshes.is_empty():
		queue_free()
		return

	for mesh in visual_meshes:
		if not is_instance_valid(mesh):
			continue

		for surface_index in range(mesh.get_surface_override_material_count()):
			var existing_override := mesh.get_surface_override_material(
				surface_index
			)

			if existing_override != null:
				var override_copy := existing_override.duplicate() as Material
				mesh.set_surface_override_material(
					surface_index,
					override_copy
				)

		for surface_index in range(mesh.get_surface_override_material_count()):
			var override_material := mesh.get_surface_override_material(
				surface_index
			)

			if override_material is BaseMaterial3D:
				override_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

		for surface_index in range(mesh.mesh.get_surface_count()):
			if mesh.get_surface_override_material(surface_index) != null:
				continue

			var original_material := mesh.get_active_material(
				surface_index
			)

			if original_material == null:
				continue

			var material_copy := original_material.duplicate() as Material

			mesh.set_surface_override_material(
				surface_index,
				material_copy
			)

			if material_copy is BaseMaterial3D:
				material_copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var tween := create_tween()
	tween.set_parallel(true)

	for mesh in visual_meshes:
		if not is_instance_valid(mesh):
			continue

		for surface_index in range(mesh.get_surface_override_material_count()):
			var material := mesh.get_surface_override_material(
				surface_index
			)

			if material is BaseMaterial3D:
				var base_material := material as BaseMaterial3D
				var final_color := base_material.albedo_color
				final_color.a = 0.0

				tween.tween_property(
					base_material,
					"albedo_color",
					final_color,
					fade_time
				)

	await tween.finished

	queue_free()


func play_animation(animation_name: String) -> void:
	if animation_player == null:
		return

	if not animation_player.has_animation(animation_name):
		push_warning(
			"Skeleton Rogue: Animation not found: " + animation_name
		)
		return

	if animation_player.current_animation == animation_name:
		return

	animation_player.play(animation_name)
