
extends Node3D

signal health_changed(current, maximum)
signal died(enemy)

# ============================================================
# STATS
# ============================================================

@export var health: float = 300.0
@export var speed: float = 2.0
@export var stop_distance: float = 0.5

@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.5
@export var attack_windup: float = 1.0
@export var attack_range: float = 0.7

@export var flinch_threshold: float = 9999.0

@export var death_wait_time: float = 3.0
@export var fade_time: float = 2.0

# ============================================================
# SUMMONS
# ============================================================

enum Cast { NONE, SUMMON, BOLT }

@export var minion_scene: PackedScene
@export var warrior_scene: PackedScene
@export var rogue_scene: PackedScene

@export var summon_cooldown: float = 10.0
@export var first_summon_delay: float = 1.5
@export var summon_radius: float = 3.0

@export_range(0.0, 1.0) var summon_damage_reduction: float = 0.5
@export var kill_summons_on_death: bool = true

# ============================================================
# BOLTS / MOVEMENT
# ============================================================

@export var bolt_scene: PackedScene
@export var bolt_damage: float = 15.0
@export var bolt_speed: float = 7.0
@export var cast_cooldown: float = 2.5
@export var cast_range: float = 12.0

@export var preferred_distance: float = 6.0
@export var retreat_distance: float = 3.0

@export var aim_height: float = 0.9
@export var bolt_spawn_height: float = 1.2

@export_range(0.0, 1.0) var summon_event_fraction: float = 0.55
@export_range(0.0, 1.0) var bolt_event_fraction: float = 0.5
@export_range(0.0, 1.0) var enrage_health_fraction: float = 0.5

# ============================================================
# NODE REFERENCES
# ============================================================

@export var model_path: NodePath = ^"Rig"
@export var animation_player_path: NodePath = ^"AnimationPlayer"
@export var fight_area_path: NodePath = ^"FightArea"

@export var model_y_rotation_degrees: float = 180.0

var model: Node3D
var animation_player: AnimationPlayer

# ============================================================
# ANIMATIONS
# ============================================================

var anim_walk_back := "Walking_Backwards"
var anim_idle_combat := "Idle_Combat"
var anim_summon := "Spellcast_Summon"
var anim_cast := "Spellcast_Shoot"

var anim_idle := "Idle"
var anim_walk := "Walking_A"
var anim_hit := "Hit_A"
var anim_death := "Death_A"
var anim_death_pose := "Death_A_Pose"
var anim_spawn := "Spawn_Ground_Skeletons"

var anim_attack_options: Array = []

var anim_awaken_options: Array = [
	"Skeletons_Awaken_Floor_Long",
	"Spawn_Ground_Skeletons"
]

var hit_seek_time := 0.05

# ============================================================
# STATE
# ============================================================

var current_cast = Cast.NONE

var cast_elapsed: float = 0.0
var cast_length: float = 0.0
var cast_event_time: float = 0.0
var cast_event_done: bool = false

var summon_timer: float = 0.0
var active_summons: Array = []
var is_enraged: bool = false

var max_health: float = 50.0

var attack_timer: float = 0.0
var attack_timer_active: float = 0.0
var is_attacking: bool = false

var player1
var player2
var target_player

var current_animation: String = ""
var attack_animations: Array = []

var is_hit: bool = false
var is_dying: bool = false

var death_timer: float = 0.0
var skeleton_meshes: Array = []

var fight_started: bool = false
var is_awakening: bool = false


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	add_to_group("enemies")

	player1 = get_tree().get_first_node_in_group("player1")
	player2 = get_tree().get_first_node_in_group("player2")

	model = get_node_or_null(model_path) as Node3D
	animation_player = get_node_or_null(animation_player_path) as AnimationPlayer

	if model == null:
		push_error(name + ": Could not find Rig at " + str(model_path))
		return

	if animation_player == null:
		push_error(name + ": Could not find AnimationPlayer at " + str(animation_player_path))
		return

	print("Skeleton Mage model found: ", model.get_path())
	print("Skeleton Mage AnimationPlayer found: ", animation_player.get_path())

	model.rotation_degrees.y = model_y_rotation_degrees

	max_health = health
	model.visible = false

	resolve_animations()
	find_meshes(model)

	var fight_area = get_node_or_null(fight_area_path)

	if fight_area is Area3D:
		fight_area.body_entered.connect(_on_fight_area_body_entered)
	else:
		push_warning(name + ": FightArea was not found or is not an Area3D.")

	summon_timer = first_summon_delay

	for anim_name in [
		anim_walk_back,
		anim_idle_combat,
		anim_summon,
		anim_cast
	]:
		validate_animation(anim_name)

	if minion_scene == null or warrior_scene == null or rogue_scene == null:
		push_warning(name + ": A summon scene is not assigned in the inspector.")

	if bolt_scene == null:
		push_warning(name + ": bolt_scene is not assigned in the inspector.")

	print("Skeleton Mage initialized successfully.")


# ============================================================
# SAFE PROPERTY HELPERS
# ============================================================

func has_property(object: Object, property_name: String) -> bool:
	if object == null:
		return false

	for property in object.get_property_list():
		if property.name == property_name:
			return true

	return false


func get_enemy_dying(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return true

	# Rogue uses is_dead.
	if has_property(enemy, "is_dead"):
		if bool(enemy.get("is_dead")):
			return true

	# Minion and Mage use is_dying.
	if has_property(enemy, "is_dying"):
		if bool(enemy.get("is_dying")):
			return true

	# Warrior uses is_alive.
	if has_property(enemy, "is_alive"):
		if not bool(enemy.get("is_alive")):
			return true

	# Rogue also tracks current_health.
	if has_property(enemy, "current_health"):
		if float(enemy.get("current_health")) <= 0.0:
			return true

	if has_property(enemy, "health"):
		if float(enemy.get("health")) <= 0.0:
			return true

	return false


func is_player_dead(player: Node) -> bool:
	if not is_instance_valid(player):
		return true

	if has_property(player, "is_dead"):
		if bool(player.get("is_dead")):
			return true

	if has_property(player, "is_alive"):
		if not bool(player.get("is_alive")):
			return true

	return false


# ============================================================
# ANIMATION HELPERS
# ============================================================

func resolve_animations() -> void:
	attack_animations.clear()

	for anim_name in anim_attack_options:
		if animation_player.has_animation(anim_name):
			attack_animations.append(anim_name)

	if attack_animations.is_empty() and not anim_attack_options.is_empty():
		push_warning(name + ": None of the attack animations exist.")

	for anim_name in [
		anim_idle,
		anim_walk,
		anim_hit,
		anim_death,
		anim_death_pose
	]:
		validate_animation(anim_name)


func validate_animation(anim_name: String) -> void:
	if not animation_player.has_animation(anim_name):
		push_warning(name + ": Missing animation '" + anim_name + "'")


func play_animation(animation_name: String) -> void:
	if animation_name == "":
		return

	if not animation_player.has_animation(animation_name):
		return

	if current_animation != animation_name:
		animation_player.play(animation_name)
		current_animation = animation_name


func animation_length(animation_name: String) -> float:
	if animation_player.has_animation(animation_name):
		return animation_player.get_animation(animation_name).length

	return 0.0


# ============================================================
# MAIN LOOP
# ============================================================

func _physics_process(delta: float) -> void:
	if is_dying:
		_process_death(delta)
		return

	if not is_instance_valid(player1):
		player1 = get_tree().get_first_node_in_group("player1")

	if not is_instance_valid(player2):
		player2 = get_tree().get_first_node_in_group("player2")

	if player1 == null and player2 == null:
		return

	if not fight_started and not is_awakening:
		return

	if is_awakening:
		var awakening_length = animation_player.current_animation_length
		var awakening_position = animation_player.current_animation_position

		if awakening_position >= awakening_length or not animation_player.is_playing():
			is_awakening = false
			fight_started = true
			play_animation(anim_idle)
			print(name, " awakened!")

		return

	if is_hit:
		var hit_length = animation_player.current_animation_length
		var hit_position = animation_player.current_animation_position

		if hit_position >= hit_length:
			is_hit = false
		else:
			return

	if attack_timer > 0:
		attack_timer -= delta

	if attack_timer_active > 0:
		attack_timer_active -= delta

	target_player = get_closest_player()

	if target_player == null:
		return

	_ai_process(delta)


# ============================================================
# DEATH PROCESSING
# ============================================================

func _process_death(delta: float) -> void:
	death_timer += delta

	if current_animation == anim_death:
		var death_length = animation_player.current_animation_length
		var death_position = animation_player.current_animation_position

		if death_position >= death_length or not animation_player.is_playing():
			play_animation(anim_death_pose)
			death_timer = 0.0

		return

	if current_animation == anim_death_pose or current_animation == "":
		if death_timer < death_wait_time:
			return

		var fade_progress = (death_timer - death_wait_time) / max(fade_time, 0.001)
		fade_progress = clamp(fade_progress, 0.0, 1.0)

		set_fade(fade_progress)

		if fade_progress >= 1.0:
			queue_free()


# ============================================================
# BOSS AI
# ============================================================

func _ai_process(delta: float) -> void:
	var flat_target: Vector3 = target_player.global_position
	flat_target.y = global_position.y

	var distance = global_position.distance_to(flat_target)

	face_position(flat_target)

	if not is_enraged and health <= max_health * enrage_health_fraction:
		is_enraged = true
		summon_cooldown *= 0.6
		cast_cooldown *= 0.6
		print(name, " is enraged!")

	active_summons = active_summons.filter(
		func(e):
			return is_instance_valid(e) and not get_enemy_dying(e)
	)

	if active_summons.is_empty() and summon_timer > 0:
		summon_timer -= delta

	if current_cast != Cast.NONE:
		cast_elapsed += delta

		if not cast_event_done and cast_elapsed >= cast_event_time:
			cast_event_done = true

			if current_cast == Cast.SUMMON:
				perform_summon()
			else:
				fire_bolt()

		if cast_elapsed >= cast_length:
			current_cast = Cast.NONE
			attack_timer = cast_cooldown
			play_animation(anim_idle_combat)

		return

	if summon_timer <= 0 and active_summons.is_empty():
		start_cast(Cast.SUMMON)
		return

	if attack_timer <= 0 and distance <= cast_range:
		start_cast(Cast.BOLT)
		return

	var direction = global_position.direction_to(flat_target)
	direction.y = 0
	direction = direction.normalized()

	var movement := Vector3.ZERO

	if distance < retreat_distance:
		movement = -direction * speed * 0.8
		play_animation(anim_walk_back)

	elif distance > preferred_distance:
		movement = direction * speed
		play_animation(anim_walk)

	else:
		play_animation(anim_idle_combat)

	global_position += movement * delta


func start_cast(kind: int) -> void:
	current_cast = kind
	cast_elapsed = 0.0
	cast_event_done = false

	var anim_name = anim_summon if kind == Cast.SUMMON else anim_cast
	var fraction = summon_event_fraction if kind == Cast.SUMMON else bolt_event_fraction

	cast_length = max(animation_length(anim_name), 0.6)
	cast_event_time = cast_length * fraction

	current_animation = ""
	play_animation(anim_name)


# ============================================================
# BOLT
# ============================================================

func fire_bolt() -> void:
	if bolt_scene == null:
		return

	if not is_instance_valid(target_player):
		return

	if is_player_dead(target_player):
		return

	var bolt = bolt_scene.instantiate()
	get_parent().add_child(bolt)

	var origin = global_position + Vector3.UP * bolt_spawn_height
	origin += -global_transform.basis.z * 0.5

	var aim_point = target_player.global_position + Vector3.UP * aim_height

	bolt.global_position = origin
	bolt.direction = origin.direction_to(aim_point)
	bolt.speed = bolt_speed
	bolt.damage = bolt_damage

	print(name, " fires a bolt at ", target_player.name)


# ============================================================
# SUMMONING
# ============================================================

func perform_summon() -> void:
	var scenes = [minion_scene, warrior_scene, rogue_scene]
	var points = get_tree().get_nodes_in_group("boss_summon_point")

	points.shuffle()

	var index = 0

	for scene in scenes:
		if scene == null:
			continue

		var summon = scene.instantiate()
		get_parent().add_child(summon)

		var spawn_position: Vector3

		if points.size() > 0:
			spawn_position = points[index % points.size()].global_position
		else:
			var angle = (TAU * index / scenes.size()) + randf() * 0.5

			spawn_position = global_position + Vector3(
				cos(angle),
				0,
				sin(angle)
			) * summon_radius

			spawn_position.y = global_position.y

		summon.global_position = spawn_position
		summon.add_to_group("boss_summons")

		wake_summon(summon)

		active_summons.append(summon)
		index += 1

	summon_timer = summon_cooldown

	print(name, " summons reinforcements!")


func wake_summon(summon: Node) -> void:
	if not is_instance_valid(summon):
		return

	# Search the root and every descendant.
	# This is important because some enemy scripts are nested
	# inside their visual model hierarchy.
	var activation_nodes: Array[Node] = [summon]

	activation_nodes.append_array(
		summon.find_children("*", "", true, false)
	)

	for enemy_node in activation_nodes:
		if not is_instance_valid(enemy_node):
			continue

		if enemy_node.has_method("activate"):
			print(
				"Skeleton Mage activating summon: ",
				enemy_node.get_path()
			)

			enemy_node.call("activate")
			return

	push_warning(
		"Skeleton Mage: Could not find an activate() function in summon: "
		+ summon.name
	)


# ============================================================
# TARGETING
# ============================================================

func face_position(world_position: Vector3) -> void:
	world_position.y = global_position.y

	if global_position.distance_to(world_position) > 0.05:
		look_at(world_position, Vector3.UP)


func get_closest_player():
	var closest_player = null
	var closest_distance = INF

	if is_instance_valid(player1) and not is_player_dead(player1):
		var d1 = global_position.distance_to(player1.global_position)

		if d1 < closest_distance:
			closest_distance = d1
			closest_player = player1

	if is_instance_valid(player2) and not is_player_dead(player2):
		var d2 = global_position.distance_to(player2.global_position)

		if d2 < closest_distance:
			closest_distance = d2
			closest_player = player2

	return closest_player


# ============================================================
# DAMAGE / DEATH
# ============================================================

func _modify_damage(amount: float) -> float:
	var alive = active_summons.filter(
		func(e):
			return is_instance_valid(e) and not get_enemy_dying(e)
	)

	if not alive.is_empty():
		return amount * (1.0 - summon_damage_reduction)

	return amount


func take_damage(amount: float) -> void:
	if is_dying:
		return

	amount = _modify_damage(amount)
	health -= amount

	health_changed.emit(max(health, 0.0), max_health)

	print(name, " health: ", health)

	if health <= 0:
		die()
		return

	if amount >= flinch_threshold:
		is_hit = true
		is_attacking = false
		attack_timer_active = 0.0

		animation_player.stop()
		current_animation = ""

		if animation_player.has_animation(anim_hit):
			animation_player.play(anim_hit)
			animation_player.seek(hit_seek_time, true)
			current_animation = anim_hit
		else:
			is_hit = false


func die() -> void:
	if is_dying:
		return

	current_cast = Cast.NONE

	if kill_summons_on_death:
		for summon in get_tree().get_nodes_in_group("boss_summons"):
			if not is_instance_valid(summon):
				continue

			if get_enemy_dying(summon):
				continue

			if summon.has_method("take_damage"):
				summon.call("take_damage", 99999)
			else:
				summon.queue_free()

	print(name, " died!")

	is_dying = true
	is_hit = false
	is_attacking = false

	death_timer = 0.0

	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)

	died.emit(self)
	play_animation(anim_death)


# ============================================================
# AWAKENING
# ============================================================

func activate(forced_animation: String = "") -> void:
	if fight_started or is_awakening or is_dying:
		return

	is_awakening = true
	model.visible = true

	print(name, " awakening!")

	var chosen = forced_animation

	if chosen == "":
		var options = anim_awaken_options.filter(
			func(a):
				return animation_player.has_animation(a)
		)

		if not options.is_empty():
			chosen = options.pick_random()

	play_animation(chosen)


func _on_fight_area_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player1") and not body.is_in_group("player2"):
		return

	activate()


# ============================================================
# FADE OUT
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
