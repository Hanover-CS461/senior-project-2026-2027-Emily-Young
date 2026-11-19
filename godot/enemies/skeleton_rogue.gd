
extends CharacterBody3D

signal health_changed(current, maximum)
signal died(enemy)

@export var health: float = 100.0
@export var speed: float = 1.2
@export var stop_distance: float = 0.05

@export var attack_damage: float = 8.0
@export var attack_range: float = 7.0
@export var attack_cooldown: float = 1.5
@export var attack_windup: float = 0.65

@export var arrow_speed: float = 18.0
@export var arrow_scene: PackedScene
@export var arrow_spawn_path: NodePath

@export_range(0.0, 1.0) var burst_chance: float = 0.08
@export_range(2, 5) var burst_shots: int = 3
@export var burst_interval: float = 0.18

@export var flinch_threshold: float = 1.0
@export var death_wait_time: float = 3.0
@export var fade_time: float = 2.0

@export_group("Movement")
@export var gravity_multiplier: float = 1.0
@export var floor_snap_distance: float = 0.3
@export var approach_speed_multiplier: float = 1.0

const MODEL_Y_ROTATION_OFFSET: float = PI
const ARROW_MODEL_CORRECTION: Vector3 = Vector3(PI / 2.0, 0.0, PI / 2.0)

const RETREAT_STOP_DISTANCE: float = 3.0
const APPROACH_STOP_DISTANCE: float = 6.5

enum MovementState {
	HOLD,
	RETREAT,
	APPROACH
}

var movement_state: MovementState = MovementState.HOLD

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
var arrow_spawn: Marker3D

var loaded_arrow: Area3D = null
var loaded_arrow_model: Node3D = null

var original_body_transform: Transform3D
var visual_meshes: Array[MeshInstance3D] = []

var idle_animation: String = "Rig_Medium_General/Idle_A"
var walk_animation: String = "Rig_Medium_Special/Skeletons_Walking"
var hit_animation: String = "Rig_Medium_General/Hit_B"
var death_animation: String = "Rig_Medium_Special/Skeletons_Death"
var spawn_animation: String = "Rig_Medium_Special/Skeletons_Spawn_Ground"

var aiming_animation: String = "Rig_Medium_CombatRanged/Ranged_2H_Aiming"
var shoot_animation: String = "Rig_Medium_CombatRanged/Ranged_2H_Shoot"
var reload_animation: String = "Rig_Medium_CombatRanged/Ranged_2H_Reload"


func _ready() -> void:
	randomize()
	current_health = health
	floor_snap_length = floor_snap_distance

	add_to_group("enemies")
	add_to_group("rogue_room")

	model = get_parent() as Node3D

	if model == null:
		push_error("Skeleton Rogue: Could not find enemy root.")
		return

	visual_model = model.get_node_or_null("Rig_Medium") as Node3D

	if visual_model == null:
		push_error("Skeleton Rogue: Could not find Rig_Medium.")
		return

	model.visible = false
	original_body_transform = transform

	animation_player = model.find_child(
		"AnimationPlayer", true, false
	) as AnimationPlayer

	if animation_player == null:
		push_error("Skeleton Rogue: AnimationPlayer not found.")
		return

	if arrow_spawn_path != NodePath():
		arrow_spawn = get_node_or_null(arrow_spawn_path) as Marker3D

	if arrow_spawn == null:
		push_warning("Skeleton Rogue: Arrow Spawn Marker3D not assigned.")

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

	print("Skeleton Rogue diagnostic version ready.")


func _process(_delta: float) -> void:
	if not is_instance_valid(loaded_arrow):
		return

	if not is_instance_valid(arrow_spawn):
		return

	loaded_arrow.global_position = arrow_spawn.global_position
	loaded_arrow.global_rotation = arrow_spawn.global_rotation
	loaded_arrow.scale = Vector3.ONE

	if is_instance_valid(loaded_arrow_model):
		loaded_arrow_model.rotation = ARROW_MODEL_CORRECTION


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	apply_gravity(delta)

	# DIAGNOSTIC: Disable all horizontal movement.
	# This tests whether the rogue is being moved by another transform or script.
	velocity.x = 0.0
	velocity.z = 0.0

	if not is_awake:
		play_animation(idle_animation)
	elif is_waking:
		pass
	elif is_flinching:
		pass
	elif is_attacking or not can_attack:
		if not is_attacking:
			find_nearest_player()
			if is_instance_valid(target_player):
				face_player()
			play_animation(aiming_animation)
	else:
		find_nearest_player()

		if is_instance_valid(target_player):
			face_player()
			var distance := global_position.distance_to(
				target_player.global_position
			)

			if distance <= attack_range and distance >= stop_distance:
				start_attack()
			else:
				play_animation(aiming_animation)
		else:
			play_animation(idle_animation)

	# Always keep horizontal velocity zero during this diagnostic.
	velocity.x = 0.0
	velocity.z = 0.0

	move_body_and_sync()


func apply_gravity(delta: float) -> void:
	var gravity: float = float(
		ProjectSettings.get_setting("physics/3d/default_gravity")
	)

	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= gravity * gravity_multiplier * delta


func move_body_and_sync() -> void:
	if is_dead:
		return

	move_and_slide()

	# Keep the body and parent in their original relationship.
	# No rotation synchronization.
	if model != null:
		var body_offset: Vector3 = (
			model.global_transform.basis * original_body_transform.origin
		)
		model.global_position = global_position - body_offset
		transform = original_body_transform


func face_player() -> void:
	if not is_instance_valid(target_player):
		return

	var look_position: Vector3 = target_player.global_position
	look_position.y = visual_model.global_position.y

	if visual_model.global_position.distance_to(look_position) < 0.01:
		return

	visual_model.look_at(look_position, Vector3.UP)
	visual_model.rotate_y(MODEL_Y_ROTATION_OFFSET)


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


func create_loaded_arrow() -> void:
	if is_instance_valid(loaded_arrow):
		return

	if arrow_scene == null or not is_instance_valid(arrow_spawn):
		return

	var new_arrow: Node = arrow_scene.instantiate()
	loaded_arrow = new_arrow as Area3D

	if loaded_arrow == null:
		if is_instance_valid(new_arrow):
			new_arrow.queue_free()
		push_error("Skeleton Rogue: Arrow scene root must be an Area3D.")
		return

	loaded_arrow.top_level = true

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		loaded_arrow.queue_free()
		loaded_arrow = null
		return

	scene_root.add_child(loaded_arrow)

	loaded_arrow.global_position = arrow_spawn.global_position
	loaded_arrow.global_rotation = arrow_spawn.global_rotation
	loaded_arrow.scale = Vector3.ONE

	loaded_arrow_model = loaded_arrow.get_node_or_null(
		"ArrowModel"
	) as Node3D

	if is_instance_valid(loaded_arrow_model):
		loaded_arrow_model.rotation = ARROW_MODEL_CORRECTION

	loaded_arrow.monitoring = false
	loaded_arrow.monitorable = false
	loaded_arrow.collision_layer = 0
	loaded_arrow.collision_mask = 0
	loaded_arrow.set_physics_process(false)
	loaded_arrow.set_process(false)


func remove_loaded_arrow() -> void:
	if is_instance_valid(loaded_arrow):
		loaded_arrow.queue_free()

	loaded_arrow = null
	loaded_arrow_model = null


func start_attack() -> void:
	if not can_attack or is_attacking or is_dead:
		return

	if not is_instance_valid(target_player):
		return

	if arrow_scene == null or not is_instance_valid(arrow_spawn):
		push_warning("Skeleton Rogue: Assign Arrow Scene and Arrow Spawn.")
		return

	can_attack = false
	is_attacking = true
	velocity.x = 0.0
	velocity.z = 0.0

	face_player()
	create_loaded_arrow()
	play_animation(aiming_animation)

	await get_tree().create_timer(attack_windup).timeout

	if is_dead:
		remove_loaded_arrow()
		return

	find_nearest_player()

	if not is_instance_valid(target_player):
		finish_attack()
		return

	face_player()

	var shots_to_fire: int = 1
	if randf() < burst_chance:
		shots_to_fire = burst_shots
		print("Skeleton Rogue is firing a rapid burst!")

	for shot in range(shots_to_fire):
		if is_dead:
			remove_loaded_arrow()
			return

		find_nearest_player()
		if not is_instance_valid(target_player):
			break

		face_player()
		remove_loaded_arrow()
		shoot_arrow()
		play_animation(shoot_animation)

		if shot < shots_to_fire - 1:
			create_loaded_arrow()
			await get_tree().create_timer(burst_interval).timeout

	if is_dead:
		remove_loaded_arrow()
		return

	if animation_player.has_animation(reload_animation):
		var reload_duration: float = animation_player.get_animation(
			reload_animation
		).length
		play_animation(reload_animation)
		await get_tree().create_timer(reload_duration).timeout

	if is_dead:
		remove_loaded_arrow()
		return

	create_loaded_arrow()
	finish_attack()


func shoot_arrow() -> void:
	if arrow_scene == null or not is_instance_valid(arrow_spawn):
		return
	if not is_instance_valid(target_player):
		return

	var new_arrow: Node = arrow_scene.instantiate()
	var arrow: Area3D = new_arrow as Area3D

	if arrow == null:
		new_arrow.queue_free()
		push_error("Skeleton Rogue: Fired arrow root must be an Area3D.")
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		arrow.queue_free()
		return

	scene_root.add_child(arrow)
	arrow.global_position = arrow_spawn.global_position
	arrow.scale = Vector3.ONE

	var direction: Vector3 = (
		target_player.global_position - arrow_spawn.global_position
	).normalized()

	if arrow.has_method("setup"):
		arrow.setup(direction, attack_damage, arrow_speed)


func finish_attack() -> void:
	is_attacking = false
	if is_dead:
		return

	play_animation(idle_animation)
	await get_tree().create_timer(attack_cooldown).timeout

	if not is_dead:
		can_attack = true


func _on_fight_area_body_entered(body: Node3D) -> void:
	if is_dead:
		return

	if body.is_in_group("player1") or body.is_in_group("player2"):
		wake_up()


func wake_up() -> void:
	if is_awake or is_dead:
		return

	is_awake = true
	is_waking = true
	model.visible = true

	if animation_player.has_animation(spawn_animation):
		var spawn_duration: float = animation_player.get_animation(
			spawn_animation
		).length
		play_animation(spawn_animation)
		await get_tree().create_timer(spawn_duration).timeout
	else:
		play_animation(idle_animation)

	if is_dead:
		return

	is_waking = false
	create_loaded_arrow()


func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return

	current_health -= amount
	current_health = maxf(current_health, 0.0)
	health_changed.emit(current_health, health)

	print("Skeleton Rogue health: ", current_health, "/", health)

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
	can_attack = false
	velocity.x = 0.0
	velocity.z = 0.0

	remove_loaded_arrow()

	if animation_player.has_animation(hit_animation):
		var hit_duration: float = animation_player.get_animation(
			hit_animation
		).length
		play_animation(hit_animation)
		await get_tree().create_timer(hit_duration).timeout

	if is_dead:
		return

	is_flinching = false
	can_attack = true
	create_loaded_arrow()


func die() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	is_flinching = false
	is_waking = false

	remove_loaded_arrow()
	velocity = Vector3.ZERO
	remove_from_group("rogue_room")

	print(
		"Skeleton Rogue defeated! Remaining rogues: ",
		get_tree().get_nodes_in_group("rogue_room").size()
	)

	if fight_area != null:
		fight_area.monitoring = false

	died.emit(self)

	if animation_player.has_animation(death_animation):
		var death_duration: float = animation_player.get_animation(
			death_animation
		).length
		play_animation(death_animation)
		await get_tree().create_timer(death_duration).timeout

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
		if not is_instance_valid(mesh) or mesh.mesh == null:
			continue

		for surface_index in range(mesh.mesh.get_surface_count()):
			var original_material := mesh.get_active_material(surface_index)
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
		if not is_instance_valid(mesh) or mesh.mesh == null:
			continue

		for surface_index in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_surface_override_material(surface_index)

			if material is BaseMaterial3D:
				var final_color: Color = material.albedo_color
				final_color.a = 0.0
				tween.tween_property(
					material,
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
		push_warning("Skeleton Rogue: Animation not found: " + animation_name)
		return

	if animation_player.current_animation == animation_name:
		return

	animation_player.play(animation_name)
