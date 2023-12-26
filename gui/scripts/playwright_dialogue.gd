@tool
extends GraphNode

@onready var dialogue_vbox: VBoxContainer = $DialogueVBox
@onready var speaker_line_edit: LineEdit = $DialogueVBox/SpeakerLineEdit
@onready var dialogue_type_button: OptionButton = $DialogueVBox/DialogueTypeOptionButton
@onready var add_line_button: Button = $DialogueVBox/AddLineButton
@onready var dialogue_text_edit: TextEdit = $DialogueTextEdit
@onready var next_dialogue_label: Label = $NextDialogueLabel

signal delete_node(node: GraphNode)

var dialogue_type: Dialogue.DialogueType = Dialogue.DialogueType.DEFAULT
var slot_index: int = 2

func _ready():
	set_slot(0, false, 1, Color.WHITE, true, 1, Color.PURPLE)
	set_slot(1, true, 1, Color.PURPLE, false, 0, Color.WHITE)
	set_slot_color_left(slot_index, Color.ROYAL_BLUE)
	set_slot_color_right(slot_index, Color.WEB_GREEN)

func _unhandled_input(event: InputEvent):
	if selected:
		if event is InputEventKey and event.is_pressed():
			#print(OS.get_keycode_string(event.keycode))
			if OS.get_keycode_string(event.keycode) == "Kp Period":
				var playwright_graph: GraphEdit = get_parent()
				delete_node.emit(self)

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
