@tool
extends PlaywrightAction

class_name PlaywrightParallelActionContainer

@onready var parallel_action_label: Label = $ParallelActionLabel

var slot_counter: int = 3
var action_counter: int = 1

func _on_add_parallel_action_button_pressed():
	var new_label: Label = parallel_action_label.duplicate()
	add_child(new_label)
	
	action_counter += 1
	new_label.text = "Parallel Action " + str(action_counter)
	
	slot_counter += 1
	set_slot_enabled_left(slot_counter, true)
	set_slot_color_left(slot_counter, get_slot_color_left(3))
	set_slot_type_left(slot_counter, 0)
