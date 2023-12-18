@tool
extends GraphNode

@onready var dialogue_vbox: VBoxContainer = $DialogueVBox
@onready var speaker_line_edit: LineEdit = $DialogueVBox/SpeakerLineEdit
@onready var dialogue_type_button: OptionButton = $DialogueVBox/DialogueTypeOptionButton
@onready var add_line_button: Button = $DialogueVBox/AddLineButton
@onready var dialogue_text_edit: TextEdit = $DialogueTextEdit

var dialogue_type: Dialogue.DialogueType = Dialogue.DialogueType.DEFAULT
var slot_index: int = 1

func _ready():
	set_slot_color_left(slot_index, Color.hex(0x4781d1))
	set_slot_color_right(slot_index, Color.hex(0xb74243))

func _on_dialogue_type_option_button_item_selected(index: int):
	dialogue_type = index
	match index:
		0:
			add_line_button.text = "Add Line"
		1: 
			add_line_button.text = "Add Response"
		_:
			add_line_button.text = "Add Other"

func _on_add_line_button_pressed():
	var new_dialogue_text: TextEdit = dialogue_text_edit.duplicate()
	new_dialogue_text.text = ""
	add_child(new_dialogue_text)
	
	slot_index += 1
	#call_deferred("set_slot", true, 0, Color.BLUE, true, 0, Color.RED)
	set_slot(slot_index, true, 0, Color.hex(0x4781d1), true, 0, Color.hex(0xb74243))


