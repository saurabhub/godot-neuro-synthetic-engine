extends Control
class_name UIDashboard

## Real-time analytics overlay showing: Frame Rate, 
## Data Points Collected, and Mean Distance to Target.

var fps_label: Label
var data_count_label: Label
var mean_dist_label: Label

var total_distance_sum: float = 0.0
var distance_samples: int = 0

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_left", 20)
	canvas_layer.add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "Neural Data Generation Engine [Live]"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	vbox.add_child(title)
	
	fps_label = Label.new()
	fps_label.text = "FPS: 0"
	vbox.add_child(fps_label)
	
	data_count_label = Label.new()
	data_count_label.text = "Data Collected: 0"
	vbox.add_child(data_count_label)
	
	mean_dist_label = Label.new()
	mean_dist_label.text = "Mean Dist to Target: 0.00m"
	vbox.add_child(mean_dist_label)

func _process(delta: float) -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	
	if DataNexusSingleton != null and DataNexus:
		data_count_label.text = "Data Collected: %d rows" % DataNexus.get_data_count()
		
	_calculate_mean_distance()

func _calculate_mean_distance() -> void:
	# Calculate instantaneous distance from Agent(s) to Target
	var agent_dist_sum = 0.0
	var agent_count = 0
	
	# Fallback to traversing tree if groups are not heavily utilized
	var root = get_tree().root
	_find_agents_recursive(root, agent_dist_sum, agent_count)

func _find_agents_recursive(node: Node, sum_ref: float, count_ref: int) -> void:
	for child in node.get_children():
		if child is AgentBrain and child.target_node:
			var dist = child.global_position.distance_to(child.target_node.global_position)
			
			total_distance_sum += dist
			distance_samples += 1
			
			mean_dist_label.text = "Mean Dist to Target: %.2fm" % (total_distance_sum / float(distance_samples))
			return # Simple assumption: just update on first find or accumulate
		_find_agents_recursive(child, sum_ref, count_ref)
