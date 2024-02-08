@tool
extends PlaywrightAction

class_name PlaywrightActionAnimation

@onready var anim_path: LineEdit = $AnimationPathLineEdit
@onready var node_name: LineEdit = $NodeNameLineEdit
@onready var property_name: LineEdit = $PropertyNameLineEdit
@onready var anim_track: LineEdit = $AnimationTrackLineEdit
@onready var node_local_anim: LineEdit = $NodeLocalAnimationNameLineEdit
