extends Snake

func _ready() -> void:
	super._ready()
	set_process_input(true)

func _input(event: InputEvent) -> void:
	var new_direction: Vector2i
	
	if event.is_action_pressed("ui_up"):
		new_direction = Vector2i(0, -1)
	elif event.is_action_pressed("ui_down"):
		new_direction = Vector2i(0, 1)
	elif event.is_action_pressed("ui_left"):
		new_direction = Vector2i(-1, 0)
	elif event.is_action_pressed("ui_right"):
		new_direction = Vector2i(1, 0)
	else:
		return
	
	# Try to buffer the move first
	buffer_move(new_direction)
	
	# If buffering failed, try to set as requested direction
	if _is_valid_direction_change(current_direction, new_direction):
		requested_direction = new_direction

func next_move() -> Vector2i:
	return current_direction 
