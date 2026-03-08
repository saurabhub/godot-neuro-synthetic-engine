extends CharacterBody3D
class_name AgentBrain

## The AI Agent (Vision-Based Reasoning)
## CharacterBody3D agent with a 360-degree RayCast3D array.
## Perceives obstacles, distances, and target vectors via Cognitive State Machine.

enum State { EXPLORE, PURSUE, RECOVER, EVADE }

@export var move_speed: float = 6.0
@export var rotation_speed: float = 5.0
@export var safe_distance: float = 2.5
@export var max_ray_distance: float = 12.0
@export var ray_count: int = 8

var current_state: State = State.EXPLORE
var current_trigger: String = "Init"
var raycasts: Array[RayCast3D] = []
var target_node: Node3D
var agent_id: String

func _ready() -> void:
	# Use instance ID or random string for multi-agent support
	agent_id = "Agent_%d" % get_instance_id()
	_setup_sensors()
	
	# Simple mesh representation for the agent
	var mesh = MeshInstance3D.new()
	mesh.mesh = CapsuleMesh.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0.8, 1.0)
	mesh.material_override = mat
	add_child(mesh)
	
	var coll = CollisionShape3D.new()
	coll.shape = CapsuleShape3D.new()
	add_child(coll)

func _setup_sensors() -> void:
	var angle_step = TAU / float(ray_count)
	for i in range(ray_count):
		var ray = RayCast3D.new()
		ray.target_position = Vector3(0, 0, -max_ray_distance)
		# Spread horizontally in 360 degrees
		ray.rotation = Vector3(0, float(i) * angle_step, 0)
		ray.position = Vector3(0, 0.5, 0) # elevated slightly from base
		add_child(ray)
		raycasts.append(ray)

func _find_target() -> void:
	var targets = get_tree().get_nodes_in_group("Targets")
	if targets.size() > 0:
		target_node = targets[0]

func _physics_process(delta: float) -> void:
	if not target_node:
		_find_target()
		if not target_node:
			return # Can't operate without a target right now
			
	_run_state_machine(delta)
	
	# Velocity is updated internally by states
	move_and_slide()
	
	_log_decision_metadata()

func _run_state_machine(delta: float) -> void:
	var features = _get_feature_vector()
	var min_dist = max_ray_distance
	for dist in features:
		if dist < min_dist:
			min_dist = dist
			
	var is_target_visible = _can_see_target()
	
	match current_state:
		State.EXPLORE:
			if is_target_visible:
				_transition_to(State.PURSUE, "Target_Sighted")
			elif min_dist < safe_distance:
				_transition_to(State.EVADE, "Collision_Imminent")
			else:
				_wander(delta)
				
		State.PURSUE:
			if not is_target_visible:
				_transition_to(State.EXPLORE, "LineOfSight_Lost")
			elif min_dist < safe_distance:
				_transition_to(State.RECOVER, "Obstacle_In_Path")
			else:
				_move_towards_target(delta)
				
		State.RECOVER:
			if min_dist >= safe_distance:
				if is_target_visible:
					_transition_to(State.PURSUE, "Path_Clear_Pursue")
				else:
					_transition_to(State.EXPLORE, "Path_Clear_Explore")
			else:
				_steer_away_from_obstacles(delta, features)
				
		State.EVADE:
			if min_dist >= safe_distance * 1.5:
				_transition_to(State.EXPLORE, "Safe_Distance_Reached")
			else:
				_steer_away_from_obstacles(delta, features)

func _transition_to(new_state: State, trigger: String) -> void:
	if current_state != new_state:
		current_state = new_state
		current_trigger = trigger

func _get_feature_vector() -> Array[float]:
	var features: Array[float] = []
	for ray in raycasts:
		ray.force_raycast_update()
		if ray.is_colliding():
			var hit_point = ray.get_collision_point()
			features.append(global_position.distance_to(hit_point))
		else:
			features.append(max_ray_distance)
	return features

func _get_angle_to_target() -> float:
	if not target_node:
		return 0.0
	var dir_to_target = global_position.direction_to(target_node.global_position)
	var forward = -global_transform.basis.z.normalized()
	# Calculate signed angle in XZ plane
	return forward.signed_angle_to(dir_to_target, Vector3.UP)

func _can_see_target() -> bool:
	if not target_node:
		return false
	var space_state = get_world_3d().direct_space_state
	# Cast from eye level
	var start_pos = global_position + Vector3(0, 1.0, 0)
	var end_pos = target_node.global_position + Vector3(0, 1.0, 0)
	
	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	query.exclude = [self.get_rid()]
	
	var result = space_state.intersect_ray(query)
	# If we hit nothing or we hit the target
	if result.is_empty():
		return true
	if result.has("collider") and result.collider == target_node:
		return true
	return false

# Movement Behaviours

func _wander(delta: float) -> void:
	# Mild random steering change
	rotate_y(randf_range(-1.0, 1.0) * rotation_speed * delta * 0.2)
	var forward = -global_transform.basis.z.normalized()
	velocity = forward * (move_speed * 0.6)

func _move_towards_target(delta: float) -> void:
	var dir_to_target = global_position.direction_to(target_node.global_position)
	dir_to_target.y = 0
	dir_to_target = dir_to_target.normalized()
	
	# Calculate target rotation Y
	var target_rotation_y = atan2(dir_to_target.x, dir_to_target.z)
	
	# Smooth rotation towards target
	# Note: atan2(x, z) assumes Godot's Forward (-Z).
	var current_y = rotation.y
	rotation.y = lerp_angle(current_y, target_rotation_y, rotation_speed * delta)
	
	var forward = -global_transform.basis.z.normalized()
	velocity = forward * move_speed

func _steer_away_from_obstacles(delta: float, features: Array[float]) -> void:
	var best_idx = -1
	var max_dist = -1.0
	
	# Find safest ray angle
	for i in range(features.size()):
		if features[i] > max_dist:
			max_dist = features[i]
			best_idx = i
			
	if best_idx != -1:
		var target_relative_angle = float(best_idx) / float(ray_count) * TAU
		rotation.y = lerp_angle(rotation.y, rotation.y + target_relative_angle, rotation_speed * delta)
	
	# Move slower when evading/recovering
	var forward = -global_transform.basis.z.normalized()
	velocity = forward * (move_speed * 0.4)

func _log_decision_metadata() -> void:
	var state_str = State.keys()[current_state]
	var features = _get_feature_vector()
	var angle = _get_angle_to_target()
	
	DataNexus.log_agent_data(
		agent_id, 
		global_position, 
		state_str, 
		features, 
		angle, 
		current_trigger
	)
	
	# Reset trigger logging mechanically so continuous state doesn't look like infinite triggers
	if current_trigger != "None":
		current_trigger = "None"
