@tool
extends GraphNode

@onready var parallel_action_label: Label = $ParallelActionLabel

var slot_counter: int = 3
var action_counter: int = 1

func _ready():
	pass

func _process(delta):
	pass

func _on_add_parallel_action_button_pressed():
	var new_label: Label = parallel_action_label.duplicate()
	add_child(new_label)
	
	action_counter += 1
	new_label.text = "Parallel Action " + str(action_counter)
	
	slot_counter += 1
	set_slot_enabled_left(slot_counter, true)
	set_slot_color_left(slot_counter, Color(78, 140, 233, 255))
	set_slot_type_left(slot_counter, 2)
