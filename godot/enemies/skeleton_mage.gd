extends CharacterBody3D
## Skeleton Mage - final boss. Keeps range, fires bolts, summons a Minion + Warrior + Rogue
## when none are alive; takes reduced damage while summons live; summons collapse on its death.
## Fully standalone (no shared base class).

signal health_changed(current, maximum)
signal died(enemy)

# ============================================================
# STATS (tweakable per enemy in the inspector)
# ============================================================

@export var health: float = 300.0
@export var speed: float = 2.0
@export var stop_distance: float = 0.5

@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.5
@export var attack_windup: float = 1.0
@export var attack_range: float = 0.7

## Hits weaker than this don't interrupt the enemy with a flinch.
@export var flinch_threshold: float = 9999.0

@export var death_wait_time: float = 3.0
@export var fade_time: float = 2.0

# ============================================================
# BOSS SETTINGS
# ============================================================

enum Cast { NONE, SUMMON, BOLT }

# ============================================================
# SUMMONS
# ============================================================

@export var minion_scene: PackedScene
@export var warrior_scene: PackedScene
@export var rogue_scene: PackedScene

## Seconds between waves, counted from the moment the last summon dies.
@export var summon_cooldown: float = 10.0
@export var first_summon_delay: float = 1.5

## Spawn ring around the boss. If you place Marker3Ds in the group
## "boss_summon_point" in the room, those are used instead.
@export var summon_radius: float = 3.0

## Damage reduction while at least one summon is alive (0.5 = half damage).
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

## Walk toward the player if farther than this...
@export var preferred_distance: float = 6.0
## ...and back away if closer than this.
@export var retreat_distance: float = 3.0

## Height above the target's origin that bolts aim at.
@export var aim_height: float = 0.9
## Height above the boss's origin that bolts spawn at.
@export var bolt_spawn_height: float = 1.2

## When in each cast animation the effect happens (0 = start, 1 = end).
@export_range(0.0, 1.0) var summon_event_fraction: float = 0.55
@export_range(0.0, 1.0) var bolt_event_fraction: float = 0.5

## Below this fraction of health the boss casts/summons faster.
@export_range(0.0, 1.0) var enrage_health_fraction: float = 0.5

var anim_walk_back := "Walking_Backwards"
var anim_idle_combat := "Idle_Combat"
var anim_summon := "Spellcast_Summon"
var anim_cast := "Spellcast_Shoot"

var current_cast = Cast.NONE
var cast_elapsed = 0.0
var cast_length = 0.0
var cast_event_time = 0.0
var cast_event_done = false

var summon_timer = 0.0
var active_summons: Array = []
var is_enraged = false

# ============================================================
# SETUP VALUES (subclasses change these in _init)
# ============================================================

var model_name := "Skeleton_Mage"

var anim_idle := "Idle"
var anim_walk := "Walking_A"
var anim_hit := "Hit_A"
var anim_death := "Death_A"
var anim_death_pose := "Death_A_Pose"
var anim_spawn := "Spawn_Ground_Skeletons"

# The mage has no melee attacks - it only casts.
var anim_attack_options: Array = []

var anim_awaken_options: Array = [
	"Skeletons_Awaken_Floor_Long",
	"Spawn_Ground_Skeletons"
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

	summon_timer = first_summon_delay

	for anim_name in [anim_walk_back, anim_idle_combat, anim_summon, anim_cast]:
		validate_animation(anim_name)

	if minion_scene == null or warrior_scene == null or rogue_scene == null:
		push_warning(name + ": a summon scene is not assigned in the inspector")

	if bolt_scene == null:
		push_warning(name + ": bolt_scene is not assigned in the inspector")


# ============================================================
# ANIMATION HELPERS
# ============================================================

func resolve_animations():

	attack_animations.clear()

	for anim_name in anim_attack_options:

		if animation_player.has_animation(anim_name):
			attack_animations.append(anim_name)

	if attack_animations.is_empty() and not anim_attack_options.is_empty():

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
# BOSS AI (replaces the melee chase/attack from the base class)
# ============================================================

func _ai_process(delta):

	var flat_target = target_player.global_position

	flat_target.y = global_position.y

	var distance = global_position.distance_to(flat_target)

	face_position(flat_target)

	# Enrage
	if not is_enraged and health <= max_health * enrage_health_fraction:

		is_enraged = true
		summon_cooldown *= 0.6
		cast_cooldown *= 0.6

		print(name, " is enraged!")

	# Forget summons that are gone
	active_summons = active_summons.filter(
		func(e): return is_instance_valid(e) and not e.is_dying
	)

	# Summon cooldown only runs while the field is clear
	if active_summons.is_empty() and summon_timer > 0:
		summon_timer -= delta

	# ---------------- CASTING ----------------

	if current_cast != Cast.NONE:

		velocity.x = 0
		velocity.z = 0

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

		move_and_slide()

		return

	# ---------------- DECIDE ----------------

	if summon_timer <= 0 and active_summons.is_empty():

		start_cast(Cast.SUMMON)
		return

	if attack_timer <= 0 and distance <= cast_range:

		start_cast(Cast.BOLT)
		return

	# ---------------- MOVE ----------------

	var direction = global_position.direction_to(flat_target)

	direction.y = 0

	direction = direction.normalized()

	if distance < retreat_distance:

		velocity.x = -direction.x * speed * 0.8
		velocity.z = -direction.z * speed * 0.8

		play_animation(anim_walk_back)

	elif distance > preferred_distance:

		velocity.x = direction.x * speed
		velocity.z = direction.z * speed

		play_animation(anim_walk)

	else:

		velocity.x = 0
		velocity.z = 0

		play_animation(anim_idle_combat)

	move_and_slide()


func start_cast(kind):

	current_cast = kind
	cast_elapsed = 0.0
	cast_event_done = false

	var anim_name = anim_summon if kind == Cast.SUMMON else anim_cast
	var fraction = (
		summon_event_fraction if kind == Cast.SUMMON else bolt_event_fraction
	)

	cast_length = max(animation_length(anim_name), 0.6)
	cast_event_time = cast_length * fraction

	# Force a restart even if the same animation just played
	current_animation = ""

	play_animation(anim_name)

	velocity.x = 0
	velocity.z = 0


# ============================================================
# BOLT
# ============================================================

func fire_bolt():

	if bolt_scene == null or target_player == null or target_player.is_dead:
		return

	var bolt = bolt_scene.instantiate()

	get_parent().add_child(bolt)

	var origin = global_position + Vector3.UP * bolt_spawn_height

	# A little in front of the boss so it doesn't spawn inside the model
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

func perform_summon():

	var scenes = [minion_scene, warrior_scene, rogue_scene]

	var points = get_tree().get_nodes_in_group("boss_summon_point")

	points.shuffle()

	var index = 0

	for scene in scenes:

		if scene == null:
			continue

		var summon = scene.instantiate()

		get_parent().add_child(summon)

		var spawn_position

		if points.size() > 0:

			spawn_position = points[index % points.size()].global_position

		else:

			var angle = (TAU * index / scenes.size()) + randf() * 0.5

			spawn_position = global_position + Vector3(
				cos(angle), 0, sin(angle)
			) * summon_radius

			spawn_position.y = global_position.y

		summon.global_position = spawn_position

		summon.add_to_group("boss_summons")

		wake_summon(summon)

		active_summons.append(summon)

		index += 1

	summon_timer = summon_cooldown

	print(name, " summons reinforcements!")


func wake_summon(summon):

	if summon.has_method("activate"):

		# Warrior / Rogue (they have activate())
		summon.activate(summon.anim_spawn)

	else:

		# Your original skeleton_minion.gd, which has no activate()
		summon.is_awakening = true
		summon.get_node("Skeleton_Minion").visible = true
		summon.play_animation("Rig_Medium_Special/Skeletons_Spawn_Ground")


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

	var alive = active_summons.filter(
		func(e): return is_instance_valid(e) and not e.is_dying
	)

	if not alive.is_empty():
		return amount * (1.0 - summon_damage_reduction)

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

	current_cast = Cast.NONE

	if kill_summons_on_death:

		for summon in get_tree().get_nodes_in_group("boss_summons"):

			if is_instance_valid(summon) and not summon.is_dying:
				summon.take_damage(99999)

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
