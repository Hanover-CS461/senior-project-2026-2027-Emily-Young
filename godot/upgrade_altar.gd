
extends Node3D

# ============================================================
# UPGRADE SETTINGS
# ============================================================

@export_group("Upgrade")
@export_enum("Vitality", "Power", "Arsenal")
var upgrade_type: String = "Vitality"

@export_group("Upgrade Settings")
@export var max_health_bonus: float = 50.0
@export var damage_multiplier: float = 1.25
@export var also_grant_weapon: bool = false

@export var weapon_scene_player1: PackedScene
@export var weapon_scene_player2: PackedScene

@export var weapon_bone_names: Array[String] = [
	"handslot.r",
	"handslot.l",
	"hand.r"
]

@export var weapon_position: Vector3 = Vector3.ZERO
@export var weapon_rotation_degrees: Vector3 = Vector3.ZERO

@export_group("Detection")
@export var detection_size: Vector3 = Vector3(2.5, 2.5, 2.5)
@export var detection_offset: Vector3 = Vector3(0, 1, 0)

@export_group("Visuals")
@export var spin_emblem: bool = true
@export var spin_speed: float = 30.0
@export var float_emblem: bool = true
@export var float_height: float = 0.12
@export var float_speed: float = 2.0

# ============================================================
# UPGRADE PROPERTY NAMES
# ============================================================

const MAX_HEALTH_NAMES: Array[String] = [
	"max_health",
	"max_hp",
	"health_max",
	"maxHealth",
	"MAX_HEALTH"
]

const HEALTH_NAMES: Array[String] = [
	"health",
	"hp",
	"current_health",
	"current_hp"
]

const DAMAGE_NAMES: Array[String] = [
	"damage",
	"attack_damage",
	"base_damage",
	"projectile_damage",
	"spell_damage",
	"melee_damage",
	"sword_damage"
]

const REFRESH_METHODS: Array[String] = [
	"update_health_bar",
	"update_health_ui",
	"update_ui",
	"refresh_health"
]

# ============================================================
# VARIABLES
# ============================================================

var claimed: Dictionary = {}
var nearby_players: Array[Node3D] = []

var detection_area: Area3D
var emblem: Node3D
var glow: Light3D
var label: Label3D

var original_emblem_position: Vector3
var original_glow_energy: float = 1.0
var base_label: String = ""

var elapsed_time: float = 0.0
var all_done: bool = false


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	add_to_group("upgrade_pads")

	emblem = find_child("Emblem", true, false) as Node3D
	glow = find_child("Glow", true, false) as Light3D
	label = find_child("Label3D", true, false) as Label3D

	if is_instance_valid(emblem):
		original_emblem_position = emblem.position

	if is_instance_valid(glow):
		original_glow_energy = glow.light_energy

	if is_instance_valid(label):
		base_label = label.text

	create_detection_area()
	refresh_visual()


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:
	elapsed_time += delta

	if not all_done and is_instance_valid(emblem):
		if spin_emblem:
			emblem.rotate_y(deg_to_rad(spin_speed * delta))

		if float_emblem:
			emblem.position.y = (
				original_emblem_position.y
				+ sin(elapsed_time * float_speed) * float_height
			)

	# Only the closest pedestal handles each player's interaction.
	for player in nearby_players.duplicate():
		if not is_instance_valid(player):
			nearby_players.erase(player)
			continue

		if not is_player_in_range(player):
			nearby_players.erase(player)
			continue

		if is_nearest_pedestal_for_player(player):
			if player_interaction_pressed(player):
				handle_player_interaction(player)


# ============================================================
# DETECTION AREA
# ============================================================

func create_detection_area() -> void:
	detection_area = Area3D.new()
	detection_area.name = "PedestalDetectionArea"
	detection_area.position = detection_offset
	detection_area.collision_layer = 0
	detection_area.collision_mask = 1
	detection_area.monitoring = true
	detection_area.monitorable = false

	var collision := CollisionShape3D.new()
	collision.name = "DetectionShape"

	var shape := BoxShape3D.new()
	shape.size = detection_size
	collision.shape = shape

	detection_area.add_child(collision)
	add_child(detection_area)

	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not is_player(body):
		return

	if not nearby_players.has(body):
		nearby_players.append(body)


func _on_body_exited(body: Node3D) -> void:
	nearby_players.erase(body)


func is_player(body: Node) -> bool:
	return (
		body.is_in_group("player1")
		or body.is_in_group("player2")
	)


func is_player_in_range(player: Node3D) -> bool:
	if not is_instance_valid(detection_area):
		return false

	return detection_area.overlaps_body(player)


func get_interaction_distance(player: Node3D) -> float:
	if not is_player_in_range(player):
		return INF

	return global_position.distance_to(player.global_position)


func is_nearest_pedestal_for_player(player: Node3D) -> bool:
	var nearest_distance: float = INF
	var nearest_pedestal: Node = null

	for pad in get_tree().get_nodes_in_group("upgrade_pads"):
		if not is_instance_valid(pad):
			continue

		if not pad.has_method("get_interaction_distance"):
			continue

		var distance: float = pad.get_interaction_distance(player)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_pedestal = pad

	return nearest_pedestal == self


# ============================================================
# INPUT
# ============================================================

func player_interaction_pressed(player: Node3D) -> bool:
	var keyboard_pressed: bool = false
	var arduino: Node = null

	if player.is_in_group("player1"):
		keyboard_pressed = Input.is_action_just_pressed("mage_interact")
		arduino = get_node_or_null("/root/ArduinoMage")

	elif player.is_in_group("player2"):
		keyboard_pressed = Input.is_action_just_pressed("p2_interact")
		arduino = get_node_or_null("/root/ArduinoKnight")

	if keyboard_pressed:
		return true

	if is_instance_valid(arduino):
		if arduino.has_method("consume_interaction"):
			if arduino.consume_interaction():
				return true
		else:
			var interaction_value = arduino.get("interact_pressed")

			if interaction_value == true:
				arduino.set("interact_pressed", false)
				return true

	return false


# ============================================================
# CHOOSING
# ============================================================

func handle_player_interaction(player: Node3D) -> bool:
	if not is_instance_valid(player):
		return false

	if not is_player_in_range(player):
		return false

	if has_chosen(player):
		popup(
			player,
			"ALREADY CHOSEN",
			Color(0.7, 0.7, 0.7)
		)
		return false

	claim(player)
	return true


func has_chosen(player: Node) -> bool:
	var player_id: int = player.get_instance_id()

	for pad in get_tree().get_nodes_in_group("upgrade_pads"):
		if not is_instance_valid(pad):
			continue

		if not pad.has_method("get_claimed"):
			continue

		var pad_claimed: Dictionary = pad.get_claimed()

		if pad_claimed.has(player_id):
			return true

	return false


func get_claimed() -> Dictionary:
	return claimed


func claim(player: Node3D) -> void:
	var player_id: int = player.get_instance_id()

	if claimed.has(player_id):
		return

	claimed[player_id] = player.name

	apply_upgrade(player)

	print(
		player.name,
		" selected the ",
		upgrade_type,
		" upgrade!"
	)

	for pad in get_tree().get_nodes_in_group("upgrade_pads"):
		if is_instance_valid(pad) and pad.has_method("refresh_visual"):
			pad.refresh_visual()


# ============================================================
# APPLY UPGRADES
# ============================================================

func apply_upgrade(player: Node3D) -> void:
	match upgrade_type:
		"Vitality":
			apply_vitality(player)

		"Power":
			apply_power(player)

			if also_grant_weapon:
				apply_arsenal(player)

		"Arsenal":
			apply_arsenal(player)


# ============================================================
# VITALITY
# ============================================================

func apply_vitality(player: Node) -> void:
	var max_prop: String = find_property(player, MAX_HEALTH_NAMES)
	var health_prop: String = find_property(player, HEALTH_NAMES)

	if max_prop == "" and health_prop == "":
		push_warning(
			"Vitality upgrade: No health property found on "
			+ player.name
		)

		popup(
			player,
			"+%d MAX HEALTH" % int(max_health_bonus),
			Color(1.0, 0.4, 0.45)
		)
		return

	var new_max: float = 0.0

	if max_prop != "":
		var old_max = player.get(max_prop)
		new_max = float(old_max) + max_health_bonus

		player.set(
			max_prop,
			cast_like(old_max, new_max)
		)

	if health_prop != "":
		var old_health = player.get(health_prop)

		if max_prop != "":
			player.set(
				health_prop,
				cast_like(old_health, new_max)
			)
		else:
			player.set(
				health_prop,
				cast_like(
					old_health,
					float(old_health) + max_health_bonus
				)
			)

	notify_player(player)

	popup(
		player,
		"+%d MAX HEALTH" % int(max_health_bonus),
		Color(1.0, 0.4, 0.45)
	)


# ============================================================
# POWER
# ============================================================

func apply_power(player: Node) -> void:
	var boosted: int = 0

	for property_name in DAMAGE_NAMES:
		if property_exists(player, property_name):
			var old_value = player.get(property_name)

			if old_value is int or old_value is float:
				player.set(
					property_name,
					cast_like(
						old_value,
						float(old_value) * damage_multiplier
					)
				)

				boosted += 1

	if boosted == 0:
		push_warning(
			"Power upgrade: No compatible damage property found on "
			+ player.name
		)

	var bonus_percent: int = int(
		round((damage_multiplier - 1.0) * 100.0)
	)

	popup(
		player,
		"+%d%% DAMAGE" % bonus_percent,
		Color(1.0, 0.7, 0.25)
	)


# ============================================================
# ARSENAL
# ============================================================

func apply_arsenal(player: Node3D) -> void:
	var is_player1: bool = player.is_in_group("player1")

	var weapon_id: String = (
		"arcane_staff" if is_player1 else "knight_sword"
	)

	if player.has_method("equip_weapon"):
		player.call("equip_weapon", weapon_id)

	if property_exists(player, "has_weapon"):
		player.set("has_weapon", true)

	player.set_meta("weapon", weapon_id)

	attach_weapon(player, weapon_id, is_player1)

	popup(
		player,
		"ARCANE STAFF" if is_player1 else "KNIGHT'S BLADE",
		Color(0.45, 0.75, 1.0)
	)


# ============================================================
# PROPERTY HELPERS
# ============================================================

func property_exists(object: Object, property_name: String) -> bool:
	for property_info in object.get_property_list():
		if property_info.name == property_name:
			return true

	return false


func find_property(object: Object, names: Array[String]) -> String:
	for property_name in names:
		if property_exists(object, property_name):
			return property_name

	return ""


func cast_like(old_value, new_value):
	if old_value is int:
		return int(round(new_value))

	return float(new_value)


func notify_player(player: Node) -> void:
	for method_name in REFRESH_METHODS:
		if player.has_method(method_name):
			player.call(method_name)


# ============================================================
# FLOATING POP-UP NOTIFICATIONS
# ============================================================

func popup(
	player: Node,
	message: String,
	color: Color
) -> void:
	var popup_label := Label3D.new()

	popup_label.text = message
	popup_label.modulate = color
	popup_label.outline_modulate = Color(0, 0, 0, 1)
	popup_label.outline_size = 12
	popup_label.font_size = 56
	popup_label.pixel_size = 0.003
	popup_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup_label.no_depth_test = true
	popup_label.position = Vector3(0, 0.9, 0)

	player.add_child(popup_label)

	var tween := popup_label.create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		popup_label,
		"position:y",
		1.6,
		2.0
	)

	tween.tween_property(
		popup_label,
		"modulate:a",
		0.0,
		2.0
	).set_delay(0.8)

	tween.chain().tween_callback(
		popup_label.queue_free
	)


# ============================================================
# PEDESTAL LABEL
# ============================================================

func player_name_from_id(player_id: int) -> String:
	for player in get_tree().get_nodes_in_group("player1"):
		if player.get_instance_id() == player_id:
			return "Mage"

	for player in get_tree().get_nodes_in_group("player2"):
		if player.get_instance_id() == player_id:
			return "Knight"

	return "?"


func update_label() -> void:
	if not is_instance_valid(label):
		return

	var text: String = base_label

	if not claimed.is_empty():
		var names: Array[String] = []

		for player_id in claimed.keys():
			names.append(
				player_name_from_id(int(player_id))
			)

		text += "\nTaken: " + ", ".join(names)

	label.text = text


# ============================================================
# REFRESH PEDESTAL VISUALS
# ============================================================

func refresh_visual() -> void:
	update_label()

	var total_players: Dictionary = {}

	for group_name in ["player1", "player2"]:
		for player in get_tree().get_nodes_in_group(group_name):
			total_players[player.get_instance_id()] = true

	var chosen_players: Dictionary = {}

	for pad in get_tree().get_nodes_in_group("upgrade_pads"):
		if not is_instance_valid(pad):
			continue

		if not pad.has_method("get_claimed"):
			continue

		var pad_claimed: Dictionary = pad.get_claimed()

		for player_id in pad_claimed.keys():
			chosen_players[player_id] = true

	if (
		not total_players.is_empty()
		and chosen_players.size() >= total_players.size()
	):
		all_done = true

		if is_instance_valid(glow):
			glow.light_energy = 0.25

		if is_instance_valid(label):
			label.modulate = Color(0.6, 0.6, 0.6, 1)


# ============================================================
# WEAPON ATTACHMENT
# ============================================================

func attach_weapon(
	player: Node3D,
	weapon_id: String,
	is_player1: bool
) -> void:
	var attach_to: Node3D = null

	var skeletons = player.find_children(
		"*",
		"Skeleton3D",
		true,
		false
	)

	if skeletons.size() > 0:
		var skeleton: Skeleton3D = skeletons[0]

		for bone_name in weapon_bone_names:
			if skeleton.find_bone(bone_name) != -1:
				var attachment := BoneAttachment3D.new()

				attachment.name = "UpgradeWeapon"
				skeleton.add_child(attachment)
				attachment.bone_name = bone_name

				attach_to = attachment
				break

	if attach_to == null:
		push_warning(
			"Upgrade pedestal: No hand bone found on "
			+ player.name
			+ ". Attaching weapon to player root."
		)

		attach_to = player

	var scene: PackedScene = (
		weapon_scene_player1 if is_player1
		else weapon_scene_player2
	)

	var weapon: Node3D

	if scene != null:
		weapon = scene.instantiate() as Node3D
	else:
		weapon = build_placeholder_weapon(weapon_id)

	if not is_instance_valid(weapon):
		push_warning("Upgrade pedestal: Weapon scene root must be Node3D.")
		return

	weapon.position = weapon_position
	weapon.rotation_degrees = weapon_rotation_degrees

	attach_to.add_child(weapon)


# ============================================================
# PLACEHOLDER WEAPON VISUALS
# ============================================================

func make_material(
	color: Color,
	metallic: float = 0.0,
	emission: bool = false
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()

	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.4

	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 3.0

	return material


func add_mesh(
	parent: Node3D,
	mesh: Mesh,
	material: Material,
	position: Vector3
) -> void:
	var instance := MeshInstance3D.new()

	instance.mesh = mesh
	instance.material_override = material
	instance.position = position

	parent.add_child(instance)


func build_placeholder_weapon(weapon_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "PlaceholderWeapon"

	if weapon_id == "arcane_staff":
		var shaft := CylinderMesh.new()

		shaft.top_radius = 0.04
		shaft.bottom_radius = 0.04
		shaft.height = 1.6

		add_mesh(
			root,
			shaft,
			make_material(Color(0.35, 0.22, 0.12)),
			Vector3(0, 0.5, 0)
		)

		var orb := SphereMesh.new()

		orb.radius = 0.13
		orb.height = 0.26

		add_mesh(
			root,
			orb,
			make_material(Color(0.4, 0.8, 1.0), 0.0, true),
			Vector3(0, 1.38, 0)
		)

		var light := OmniLight3D.new()

		light.light_color = Color(0.4, 0.8, 1.0)
		light.omni_range = 2.0
		light.light_energy = 1.0
		light.position = Vector3(0, 1.38, 0)

		root.add_child(light)

	else:
		var blade := BoxMesh.new()

		blade.size = Vector3(0.1, 1.0, 0.03)

		add_mesh(
			root,
			blade,
			make_material(Color(0.8, 0.85, 0.9), 0.9),
			Vector3(0, 0.65, 0)
		)

		var guard := BoxMesh.new()

		guard.size = Vector3(0.34, 0.06, 0.08)

		add_mesh(
			root,
			guard,
			make_material(Color(0.85, 0.65, 0.2), 0.8),
			Vector3(0, 0.12, 0)
		)

		var grip := CylinderMesh.new()

		grip.top_radius = 0.035
		grip.bottom_radius = 0.035
		grip.height = 0.25

		add_mesh(
			root,
			grip,
			make_material(Color(0.25, 0.15, 0.1)),
			Vector3(0, -0.03, 0)
		)

	return root
