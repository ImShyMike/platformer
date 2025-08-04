extends AnimatableBody2D
@export var move_distance = Vector2(500, 0)
@export var move_duration = 2.0
var start_position: Vector2
var tween: Tween

func _ready():
	start_position = global_position
	sync_to_physics = true
	
	tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "global_position", start_position + move_distance, move_duration)
	tween.tween_property(self, "global_position", start_position, move_duration)
