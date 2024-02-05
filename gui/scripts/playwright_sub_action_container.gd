@tool
extends PlaywrightAction

class_name PlaywrightSubActionContainer

@onready var sub_action_label: Label = $SubActionLabel

var slot_counter: int = 4
var action_counter: int = 1

func _on_add_sub_action_button_pressed():
	var new_label: Label = sub_action_label.duplicate()
	add_child(new_label)
	
	action_counter += 1
	new_label.text = "Sub-Action " + str(action_counter)
	
	slot_counter += 1
	set_slot_enabled_left(slot_counter, true)
	set_slot_color_left(slot_counter, get_slot_color_left(2))
	set_slot_type_left(slot_counter, 0)
