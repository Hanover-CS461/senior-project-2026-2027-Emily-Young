
extends Node3D

@export var puzzle_controller_path: NodePath

@export_group("Seal Gear Animation")
@export var gear_rotation_duration: float = 3.0
@export var gear_rotation_axis: Vector3 = Vector3.UP

@export_group("Gate Animation")
@export var gate_swing_angle_degrees: float = 90.0
@export var gate_open_duration: float = 3.0
@export var gate_swing_direction: float = -1.0

var puzzle_controller: Node
var seal_animation_started: bool = false
var gate_door_open_started: bool = false


func _ready() -> void:
	print("Ancient Seal Puzzle Room ready.")

	if puzzle_controller_path != NodePath(""):
		puzzle_controller = get_node_or_null(puzzle_controller_path)

	if puzzle_controller == null:
		var scene_root := get_tree().current_scene
		if scene_root != null:
			puzzle_controller = scene_root.find_child(
				"PuzzleController", true, false
			)

	if puzzle_controller == null:
		push_warning("Ancient Seal: PuzzleController was not found.")
		return

	print("Ancient Seal found controller: ", puzzle_controller.get_path())

	var required_signals := [
		"station_completed",
		"seal_completed",
		"gate_unlocked"
	]

	for signal_name in required_signals:
		if not puzzle_controller.has_signal(signal_name):
			push_error(
				"Ancient Seal: PuzzleController is missing signal: "
				+ signal_name
			)
			return

	if not puzzle_controller.is_connected(
		"station_completed", _on_station_completed
	):
		puzzle_controller.connect(
			"station_completed", _on_station_completed
		)

	if not puzzle_controller.is_connected(
		"seal_completed", _on_seal_completed
	):
		puzzle_controller.connect(
			"seal_completed", _on_seal_completed
		)

	if not puzzle_controller.is_connected(
		"gate_unlocked", _on_gate_unlocked
	):
		puzzle_controller.connect(
			"gate_unlocked", _on_gate_unlocked
		)

	if puzzle_controller.has_method("is_station_complete"):
		if puzzle_controller.is_station_complete("fire"):
			_on_station_completed("fire")
		if puzzle_controller.is_station_complete("ice"):
			_on_station_completed("ice")
		if puzzle_controller.is_station_complete("heal"):
			_on_station_completed("heal")

	if _controller_bool("seal_is_complete"):
		_on_seal_completed()

	if _controller_bool("gate_is_unlocked"):
		_on_gate_unlocked()


func _controller_bool(property_name: String) -> bool:
	if puzzle_controller == null:
		return false

	for property_info in puzzle_controller.get_property_list():
		if property_info.name == property_name:
			return bool(puzzle_controller.get(property_name))

	return false


func _on_station_completed(station_name: String) -> void:
	match station_name:
		"fire":
			print("Fire puzzle completed!")
			_activate_visual("Gate_Lock_Fire", Color.RED)
			_activate_visual("Seal_Symbol_Fire", Color.RED)
			_activate_visual("Gate_Symbol_Fire", Color.RED)
			_activate_visual("Conduit_Fire", Color.RED)
			_release_fire_lock()

		"ice":
			print("Ice puzzle completed!")
			_activate_visual("Seal_Symbol_Ice", Color.DEEP_SKY_BLUE)
			_activate_visual("Gate_Symbol_Ice", Color.DEEP_SKY_BLUE)
			_activate_visual("Conduit_Ice", Color.DEEP_SKY_BLUE)
			_activate_visual("Gate_Lock_Ice", Color.DEEP_SKY_BLUE)
			_release_ice_lock()

		"heal":
			print("Healing puzzle completed!")
			_activate_visual("Seal_Symbol_Heal", Color.LIME_GREEN)
			_activate_visual("Gate_Symbol_Heal", Color.LIME_GREEN)
			_activate_visual("Conduit_Heal", Color.LIME_GREEN)
			_activate_visual("Gate_Lock_Heal", Color.LIME_GREEN)
			_release_heal_lock()

		_:
			push_warning("Unknown completed station: " + station_name)


func _release_fire_lock() -> void:
	var fire_lock := _find_visual("Gate_Lock_Fire")
	if fire_lock == null:
		return
	if not fire_lock is Node3D:
		push_warning("Gate_Lock_Fire must be a Node3D.")
		return
	if fire_lock.has_meta("fire_lock_released"):
		return

	fire_lock.set_meta("fire_lock_released", true)
	print("The Fire latch is sliding left!")

	var target_position: Vector3 = (
		fire_lock.position + Vector3(-1.0, 0.0, 0.0)
	)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fire_lock, "position", target_position, 1.2)


func _release_ice_lock() -> void:
	var ice_lock := _find_visual("Gate_Lock_Ice")
	if ice_lock == null:
		return
	if not ice_lock is Node3D:
		push_warning("Gate_Lock_Ice must be a Node3D.")
		return
	if ice_lock.has_meta("ice_lock_released"):
		return

	ice_lock.set_meta("ice_lock_released", true)
	print("The Ice latch is sliding left!")

	var target_position: Vector3 = (
		ice_lock.position + Vector3(-1.0, 0.0, 0.0)
	)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ice_lock, "position", target_position, 1.2)


func _release_heal_lock() -> void:
	var heal_lock := _find_visual("Gate_Lock_Heal")
	if heal_lock == null:
		return
	if not heal_lock is Node3D:
		push_warning("Gate_Lock_Heal must be a Node3D.")
		return
	if heal_lock.has_meta("heal_lock_released"):
		return

	heal_lock.set_meta("heal_lock_released", true)
	print("The Healing latch is sliding left!")

	var target_position: Vector3 = (
		heal_lock.position + Vector3(-1.0, 0.0, 0.0)
	)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(heal_lock, "position", target_position, 1.2)


func _on_seal_completed() -> void:
	if seal_animation_started:
		return

	seal_animation_started = true
	print("The Threefold Seal is activated!")

	_activate_visual("Seal_Core", Color.CYAN)
	_activate_visual("Seal_Light", Color.CYAN)
	_activate_visual("Seal_Ring_Outer", Color.CYAN)
	_activate_visual("Seal_Ring_Middle", Color.CYAN)
	_activate_visual("Seal_Ring_Inner", Color.CYAN)

	_rotate_seal_gear("Seal_Gear_1", 1.0)
	_rotate_seal_gear("Seal_Gear_2", -1.0)
	_rotate_seal_gear("Seal_Gear_3", 1.0)
	_rotate_seal_gear("Seal_Gear_Main", -1.0)

	_activate_visual("Conduit_Gate", Color.CYAN)

	if puzzle_controller != null:
		if puzzle_controller.has_method("unlock_gate"):
			puzzle_controller.unlock_gate()


func _rotate_seal_gear(
	gear_name: String,
	direction: float
) -> void:
	var gear_node := _find_visual(gear_name)

	if gear_node == null:
		return

	if not gear_node is Node3D:
		push_warning(gear_name + " must be a Node3D.")
		return

	var gear := gear_node as Node3D
	var axis := gear_rotation_axis.normalized()

	if axis.is_zero_approx():
		axis = Vector3.UP

	print("Rotating ", gear_name, "!")

	var target_rotation: Vector3 = (
		gear.rotation
		+ axis * TAU * direction
	)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		gear,
		"rotation",
		target_rotation,
		gear_rotation_duration
	)


func _on_gate_unlocked() -> void:
	print("The Ancient Gate is unlocked!")

	_activate_visual("Gate_Glow", Color.CYAN)
	_activate_visual("Gate_Glow_Light", Color.CYAN)
	_activate_visual("Conduit_Gate", Color.CYAN)

	_remove_gate_lock_keepers()
	_open_gate_door()


func _remove_gate_lock_keepers() -> void:
	var keeper_node := _find_visual("Gate_Lock_Keepers")

	if keeper_node == null:
		return

	if keeper_node.has_meta("keepers_removed"):
		return

	keeper_node.set_meta("keepers_removed", true)
	print("Removing Gate_Lock_Keepers!")

	if keeper_node is Node3D:
		var keeper := keeper_node as Node3D
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(
			keeper,
			"scale",
			Vector3.ONE * 0.01,
			0.6
		)
		tween.tween_callback(keeper.hide)
	else:
		keeper_node.queue_free()


func _open_gate_door() -> void:
	if gate_door_open_started:
		return

	gate_door_open_started = true

	_swing_gate_door(
		"Gate_Door_R",
		"Gate_Hinge_R",
		true,
		gate_swing_direction
	)
	_swing_gate_door(
		"Gate_Door_L",
		"Gate_Hinge_L",
		false,
		-gate_swing_direction
	)


func _swing_gate_door(
	door_name: String,
	hinge_name: String,
	pivot_at_max_x: bool,
	direction: float
) -> void:
	var door_node := _find_visual(door_name)
	var hinge_node := _find_visual(hinge_name)

	if door_node == null:
		push_warning(door_name + " could not be found.")
		return

	if hinge_node == null:
		push_warning(hinge_name + " could not be found.")
		return

	if not door_node is Node3D or not hinge_node is Node3D:
		push_warning(
			door_name + " and " + hinge_name
			+ " must both be Node3D nodes."
		)
		return

	var door := door_node as Node3D
	var hinge := hinge_node as Node3D

	# Only the left door carries the three gate locks.
	var locks: Array[Node3D] = []

	if door_name == "Gate_Door_L":
		for lock_name in [
			"Gate_Lock_Fire",
			"Gate_Lock_Ice",
			"Gate_Lock_Heal"
		]:
			var lock_node := _find_visual(lock_name)

			if lock_node is Node3D:
				locks.append(lock_node as Node3D)
				print(lock_name, " will follow Gate_Door_L.")
			elif lock_node != null:
				push_warning(lock_name + " must be a Node3D.")

	# Find the hinge edge of the door's mesh in door-local space.
	var bounds := _get_door_local_bounds(door)

	if not bounds["found"]:
		push_warning(
			"Could not find a mesh under " + door_name + ". "
			+ "Using the door origin as its pivot."
		)

	var pivot_local: Vector3

	if bounds["found"]:
		var door_bounds: AABB = bounds["aabb"]
		var pivot_x: float = door_bounds.position.x

		if pivot_at_max_x:
			pivot_x += door_bounds.size.x

		pivot_local = Vector3(
			pivot_x,
			door_bounds.position.y + door_bounds.size.y * 0.5,
			door_bounds.position.z + door_bounds.size.z * 0.5
		)
	else:
		pivot_local = Vector3.ZERO

	var pivot_world: Vector3 = door.to_global(pivot_local)

	var door_start_transform: Transform3D = door.global_transform
	var hinge_start_transform: Transform3D = hinge.global_transform

	# Save each lock's starting transform relative to the door's
	# original transform. This preserves its position and orientation.
	var lock_relative_transforms: Array[Transform3D] = []

	for lock in locks:
		lock_relative_transforms.append(
			door_start_transform.affine_inverse()
			* lock.global_transform
		)

	var swing_angle: float = deg_to_rad(
		gate_swing_angle_degrees * direction
	)

	print("Swinging ", door_name, " open!")

	var animate_door := func(progress: float) -> void:
		if not is_instance_valid(door):
			return

		var angle: float = swing_angle * progress
		var rotation_basis := Basis(Vector3.UP, angle)

		var start_offset: Vector3 = (
			door_start_transform.origin - pivot_world
		)

		var rotated_offset: Vector3 = (
			rotation_basis * start_offset
		)

		var new_door_transform: Transform3D = (
			door_start_transform
		)

		new_door_transform.origin = pivot_world + rotated_offset
		new_door_transform.basis = (
			rotation_basis * door_start_transform.basis
		)

		door.global_transform = new_door_transform

		# Move all three locks using the exact same door transform.
		for lock_index in range(locks.size()):
			var lock: Node3D = locks[lock_index]

			if not is_instance_valid(lock):
				continue

			lock.global_transform = (
				new_door_transform
				* lock_relative_transforms[lock_index]
			)

		if is_instance_valid(hinge):
			var hinge_offset: Vector3 = (
				hinge_start_transform.origin - pivot_world
			)

			var new_hinge_transform: Transform3D = (
				hinge_start_transform
			)

			new_hinge_transform.origin = (
				pivot_world + rotation_basis * hinge_offset
			)

			new_hinge_transform.basis = (
				rotation_basis * hinge_start_transform.basis
			)

			hinge.global_transform = new_hinge_transform

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		animate_door,
		0.0,
		1.0,
		maxf(gate_open_duration, 0.1)
	)


func _get_door_local_bounds(door: Node3D) -> Dictionary:
	var found_mesh := false
	var min_corner := Vector3.ZERO
	var max_corner := Vector3.ZERO

	var meshes: Array[Node] = []
	_collect_meshes(door, meshes)

	for mesh_node in meshes:
		if not mesh_node is MeshInstance3D:
			continue

		var mesh_instance := mesh_node as MeshInstance3D

		if mesh_instance.mesh == null:
			continue

		var mesh_bounds: AABB = mesh_instance.mesh.get_aabb()
		var mesh_transform: Transform3D = mesh_instance.global_transform

		for x_side in range(2):
			for y_side in range(2):
				for z_side in range(2):
					var corner := Vector3(
						mesh_bounds.position.x
							+ mesh_bounds.size.x * float(x_side),
						mesh_bounds.position.y
							+ mesh_bounds.size.y * float(y_side),
						mesh_bounds.position.z
							+ mesh_bounds.size.z * float(z_side)
					)

					var world_corner: Vector3 = (
						mesh_transform * corner
					)

					var local_corner: Vector3 = (
						door.to_local(world_corner)
					)

					if not found_mesh:
						min_corner = local_corner
						max_corner = local_corner
						found_mesh = true
					else:
						min_corner = min_corner.min(local_corner)
						max_corner = max_corner.max(local_corner)

	if not found_mesh:
		return {
			"found": false,
			"aabb": AABB()
		}

	return {
		"found": true,
		"aabb": AABB(
			min_corner,
			max_corner - min_corner
		)
	}


func _collect_meshes(node: Node, meshes: Array[Node]) -> void:
	if node is MeshInstance3D:
		meshes.append(node)

	for child in node.get_children():
		_collect_meshes(child, meshes)


func _find_visual(target_name: String) -> Node:
	var found_node := find_child(target_name, true, false)

	if found_node != null:
		return found_node

	var scene_root := get_tree().current_scene

	if scene_root != null:
		found_node = scene_root.find_child(
			target_name, true, false
		)

		if found_node != null:
			return found_node

	push_warning("Could not find visual: " + target_name)
	return null


func _activate_visual(
	target_name: String,
	glow_color: Color
) -> void:
	var target := _find_visual(target_name)

	if target == null:
		return

	_activate_node_and_children(target, glow_color)


func _activate_node_and_children(
	node: Node,
	glow_color: Color
) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).visible = true

	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var surface_count := 0

		if mesh_instance.mesh != null:
			surface_count = (
				mesh_instance.mesh.get_surface_count()
			)

		for surface_index in range(surface_count):
			var active_material := (
				mesh_instance.get_active_material(surface_index)
			)

			if active_material is StandardMaterial3D:
				var glowing_material := (
					active_material.duplicate()
					as StandardMaterial3D
				)

				glowing_material.emission_enabled = true
				glowing_material.emission = glow_color
				glowing_material.emission_energy_multiplier = 2.0

				mesh_instance.set_surface_override_material(
					surface_index,
					glowing_material
				)

		if mesh_instance.material_override is StandardMaterial3D:
			var glowing_override := (
				mesh_instance.material_override.duplicate()
				as StandardMaterial3D
			)

			glowing_override.emission_enabled = true
			glowing_override.emission = glow_color
			glowing_override.emission_energy_multiplier = 2.0
			mesh_instance.material_override = glowing_override

	if node is Light3D:
		var light := node as Light3D
		light.light_color = glow_color
		light.light_energy = 2.0

	for child in node.get_children():
		_activate_node_and_children(child, glow_color)
