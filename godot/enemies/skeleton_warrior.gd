extends CharacterBody3D
## Skeleton Warrior - slow, tanky bruiser with long reach and a long wind-up.
## Fully standalone (no shared base class).

signal health_changed(current, maximum)
signal died(enemy)

# ============================================================
# STATS (tweakable per enemy in the inspector)
# ============================================================

@export var health: float = 120.0
@export var speed: float = 1.4
@export var stop_distance: float = 0.9

@export var attack_damage: float = 25.0
@export var attack_cooldown: float = 2.2
@export var attack_windup: float = 1.3
@export var attack_range: float = 1.2

## Hits weaker than this don't interrupt the enemy with a flinch.
@export var flinch_threshold: float = 20.0

@export var death_wait_time: float = 3.0
@export var fade_time: float = 2.0

# ============================================================
# SETUP VALUES (subclasses change these in _init)
# ============================================================

var model_name := "Skeleton_Warrior"

var anim_idle := "Rig_Medium_General/Idle_A"
var anim_walk := "Rig_Medium_Special/Skeletons_Walking"
var anim_hit := "Rig_Medium_General/Hit_B"
var anim_death := "Rig_Medium_Special/Skeletons_Death"
var anim_death_pose := "Rig_Medium_Special/Skeletons_Death_Pose"
var anim_spawn := "Rig_Medium_Special/Skeletons_Spawn_Ground"

# Every attack animation that exists is used (picked at random each
# attack). The punch is a fallback.
var anim_attack_options: Array = [
	"Rig_Medium_CombatMelee/Melee_2H_Attack_Chop",
	"Rig_Medium_CombatMelee/Melee_2H_Attack_Slice",
	"Rig_Medium_CombatMelee/Melee_Unarmed_Attack_Punch_A"
]

var anim_awaken_options: Array = [
	"Rig_Medium_Special/Skeletons_Awaken_Floor_Long",
	"Rig_Medium_Special/Skeletons_Spawn_Ground"
]

var hit_seek_time := 0.05

# ============================================================
# STATE
# ============================================================

var max_health: float = 50.0

var attack_timer = 0.0
var attack_timer_active = 0.0
var is_attacking = false

var player1
var player2
var target_player

var model
var animation_player
var current_animation = ""
var attack_animations: Array = []

var is_hit = false
var is_dying = false

var death_timer = 0.0

var skeleton_meshes = []

# Fight room
var fight_started = false
var is_awakening = false


func _ready():

	add_to_group("enemies")

	player1 = get_tree().get_first_node_in_group("player1")
	player2 = get_tree().get_first_node_in_group("player2")

	model = get_node(model_name)

	animation_player = model.find_child("AnimationPlayer", true, false)

	max_health = health

	# Hide skeleton until a player enters the fight room
	model.visible = false

	resolve_animations()

	play_animation(anim_idle)

	find_meshes(model)

	if has_node("FightArea"):
		$FightArea.body_entered.connect(_on_fight_area_body_entered)


# ============================================================
# ANIMATION HELPERS
# ============================================================

func resolve_animations():

	attack_animations.clear()

	for anim_name in anim_attack_options:

		if animation_player.has_animation(anim_name):
			attack_animations.append(anim_name)

	if attack_animations.is_empty():

		push_warning(
			name + ": none of the attack animations exist: "
			+ str(anim_attack_options)
		)

	for anim_name in [
		anim_idle, anim_walk, anim_hit,
		anim_death, anim_death_pose
	]:

		validate_animation(anim_name)


func validate_animation(anim_name: String):

	if not animation_player.has_animation(anim_name):

		push_warning(name + ": missing animation '" + anim_name + "'")


func play_animation(animation_name: String):

	if animation_name == "" or not animation_player.has_animation(animation_name):
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

func _physics_process(delta):

	# If neither player exists, do nothing
	if player1 == null and player2 == null:
		return

	# DEATH
	if is_dying:
		_process_death(delta)
		return

	# WAITING FOR PLAYER
	if not fight_started and not is_awakening:

		velocity.x = 0
		velocity.z = 0

		move_and_slide()

		return

	# AWAKENING
	if is_awakening:

		velocity.x = 0
		velocity.z = 0

		var awakening_length = animation_player.current_animation_length
		var awakening_position = animation_player.current_animation_position

		if awakening_position >= awakening_length or not animation_player.is_playing():

			is_awakening = false
			fight_started = true

			play_animation(anim_idle)

			print(name, " awakened!")

		move_and_slide()

		return

	# HIT ANIMATION
	if is_hit:

		var hit_length = animation_player.current_animation_length
		var hit_position = animation_player.current_animation_position

		if hit_position >= hit_length:

			is_hit = false

		else:

			velocity.x = 0
			velocity.z = 0

			move_and_slide()

			return

	# TIMERS
	if attack_timer > 0:
		attack_timer -= delta

	if attack_timer_active > 0:
		attack_timer_active -= delta

	# FIND CLOSEST ALIVE PLAYER
	target_player = get_closest_player()

	if target_player == null:

		velocity.x = 0
		velocity.z = 0

		move_and_slide()

		return

	_ai_process(delta)


func _process_death(delta):

	death_timer += delta

	if current_animation == anim_death:

		var death_length = animation_player.current_animation_length
		var death_position = animation_player.current_animation_position

		if death_position >= death_length:

			play_animation(anim_death_pose)

			death_timer = 0.0

		return

	# No death pose available (or already finished): just fade out
	if current_animation == anim_death_pose or current_animation == "":

		if death_timer < death_wait_time:
			return

		var fade_progress = (death_timer - death_wait_time) / fade_time

		fade_progress = clamp(fade_progress, 0.0, 1.0)

		set_fade(fade_progress)

		if fade_progress >= 1.0:
			queue_free()


# ============================================================
# MELEE AI (default behaviour - the boss overrides this)
# ============================================================

func _ai_process(_delta):

	# ATTACKING
	if is_attacking:

		# If the target died while preparing the attack, cancel it.
		if target_player.is_dead:

			is_attacking = false
			attack_timer_active = 0.0

			play_animation(anim_idle)

			return

		face_position(target_player.global_position)

		velocity.x = 0
		velocity.z = 0

		move_and_slide()

		if attack_timer_active <= 0:

			var distance = global_position.distance_to(
				target_player.global_position
			)

			if distance <= attack_range:

				if not target_player.is_dead:

					if target_player.has_method("take_damage"):
						target_player.take_damage(attack_damage)

					print(name, " hits ", target_player.name, "!")

			else:

				print(name, " missed!")

			is_attacking = false
			attack_timer = attack_cooldown

		return

	# CHASING
	var target_position = target_player.global_position

	target_position.y = global_position.y

	var distance = global_position.distance_to(target_position)

	if distance > stop_distance:

		var direction = global_position.direction_to(target_position)

		direction.y = 0

		direction = direction.normalized()

		velocity.x = direction.x * speed
		velocity.z = direction.z * speed

		face_position(target_position)

		play_animation(anim_walk)

		move_and_slide()

	else:

		velocity.x = 0
		velocity.z = 0

		move_and_slide()

		if attack_timer <= 0:
			attack()
		else:
			play_animation(anim_idle)


func attack():

	# Make sure there is still an alive target.
	if target_player == null or target_player.is_dead:
		return

	print(name, " starts attacking ", target_player.name, "!")

	is_attacking = true

	face_position(target_player.global_position)

	attack_timer_active = attack_windup

	if not attack_animations.is_empty():

		# Force a restart even if the same attack is picked twice in a row
		current_animation = ""

		play_animation(attack_animations.pick_random())


func face_position(world_position: Vector3):

	world_position.y = global_position.y

	if global_position.distance_to(world_position) > 0.05:

		look_at(world_position, Vector3.UP)


func get_closest_player():

	var closest_player = null
	var closest_distance = INF

	if player1 != null and not player1.is_dead:

		var d1 = global_position.distance_to(player1.global_position)

		if d1 < closest_distance:
			closest_distance = d1
			closest_player = player1

	if player2 != null and not player2.is_dead:

		var d2 = global_position.distance_to(player2.global_position)

		if d2 < closest_distance:
			closest_distance = d2
			closest_player = player2

	return closest_player


# ============================================================
# DAMAGE / DEATH
# ============================================================

func _modify_damage(amount):
	return amount


func take_damage(amount):

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


func die():

	print(name, " died!")

	is_dying = true
	is_hit = false
	is_attacking = false

	death_timer = 0.0

	# Dead bodies shouldn't block or push the players
	for child in get_children():

		if child is CollisionShape3D:
			child.set_deferred("disabled", true)

	died.emit(self)

	play_animation(anim_death)


# ============================================================
# AWAKENING (fight room trigger OR boss summon)
# ============================================================

## Wakes the enemy up. Pass an animation name to force a specific
## awakening (the boss uses anim_spawn for summons).
func activate(forced_animation: String = ""):

	if fight_started or is_awakening or is_dying:
		return

	is_awakening = true

	model.visible = true

	print(name, " awakening!")

	var chosen = forced_animation

	if chosen == "":

		var options = anim_awaken_options.filter(
			func(a): return animation_player.has_animation(a)
		)

		if not options.is_empty():
			chosen = options.pick_random()

	play_animation(chosen)


func _on_fight_area_body_entered(body):

	if not body.is_in_group("player1") and not body.is_in_group("player2"):
		return

	activate()


# ============================================================
# FADE OUT
# ============================================================

func find_meshes(node):

	for child in node.get_children():

		if child is MeshInstance3D:
			skeleton_meshes.append(child)

		if child.get_child_count() > 0:
			find_meshes(child)


func set_fade(amount):

	for mesh in skeleton_meshes:

		if mesh == null or mesh.mesh == null:
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

			material.albedo_color.a = 1.0 - amount
