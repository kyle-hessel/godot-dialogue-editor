@tool
extends PlaywrightAction

class_name PlaywrightArrayAction

@onready var array_action_label: Label = $ArrayActionLabel
@onready var array_option_button: OptionButton = $ArrayOptionButton

var slot_counter: int = 5
var action_counter: int = 1

func _on_add_array_button_pressed():
	var new_label: Label = array_action_label.duplicate()
	add_child(new_label)
	
	action_counter += 1
	new_label.text = "Array Action " + str(action_counter)
	
	slot_counter += 1
	set_slot_enabled_left(slot_counter, true)
	set_slot_color_left(slot_counter, get_slot_color_left(5))
	set_slot_type_left(slot_counter, 0)
