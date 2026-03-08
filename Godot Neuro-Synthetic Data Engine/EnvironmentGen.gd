extends Node3D
class_name EnvironmentGen

## Environment Manager
## Procedurally generates a 3D arena with randomized static obstacles
## and dynamic Target entities to ensure dataset diversity.

@export var arena_size: float = 20.0
@export var obstacle_count: int = 15

var obstacles: Array[Node3D] = []
var targets: Array[Node3D] = []

func _ready() -> void:
	generate_arena()
	spawn_obstacles()
	call_deferred("spawn_target") # Ensure arena is ready before target spawn

func generate_arena() -> void:
	var ground = CSGBox3D.new()
	ground.size = Vector3(arena_size, 1.0, arena_size)
	ground.position = Vector3(0, -0.5, 0)
	ground.use_collision = true
	
	# Basic visual material for ground
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.2, 0.2)
	ground.material_override = material
	
	add_child(ground)
	
func spawn_obstacles() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.4, 0.6)
	
	for i in range(obstacle_count):
		var obs = CSGBox3D.new()
		# Randomize dimensions (W, H, D)
		obs.size = Vector3(rng.randf_range(1.0, 3.0), rng.randf_range(2.0, 5.0), rng.randf_range(1.0, 3.0))
		
		# Place within arena bounds, avoiding the absolute edges
		var bound = (arena_size / 2.0) - 2.0
		var x_pos = rng.randf_range(-bound, bound)
		var z_pos = rng.randf_range(-bound, bound)
		
		obs.position = Vector3(x_pos, obs.size.y / 2.0, z_pos)
		obs.use_collision = true
		obs.material_override = mat
		
		add_child(obs)
		obstacles.append(obs)

func spawn_target() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var target_area = Area3D.new()
	target_area.name = "TargetArea"
	
	var coll = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.0
	coll.shape = shape
	target_area.add_child(coll)
	
	var bound = (arena_size / 2.0) - 2.0
	var x_pos = rng.randf_range(-bound, bound)
	var z_pos = rng.randf_range(-bound, bound)
	target_area.position = Vector3(x_pos, 1.0, z_pos)
	
	# Assign target to a Godot group to easily find it later
	target_area.add_to_group("Targets")
	
	# Mesh for visual identification
	var mesh_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 1.0
	sphere_mesh.height = 2.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.1, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.2)
	mesh_instance.mesh = sphere_mesh
	mesh_instance.material_override = mat
	target_area.add_child(mesh_instance)
	
	add_child(target_area)
	targets.append(target_area)
