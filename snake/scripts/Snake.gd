extends Node2D
class_name Snake

# Grid configuration
const GRID_SIZE_X: int = GameConfig.GRID_SIZE_X
const GRID_SIZE_Y: int = GameConfig.GRID_SIZE_Y
const CELL_SIZE: int = GameConfig.CELL_SIZE

# Movement directions using vectors
var current_direction: Vector2i = Vector2i(1, 0)  # Start moving right
var requested_direction: Vector2i = Vector2i(1, 0)  # Direction requested by input
var move_buffer: Array[Vector2i] = []  # Buffer for next moves (max 1)

# Snake body management
var body_segments: Array[Vector2i] = []
var head_position: Vector2i
var tail_position: Vector2i

var body_color: Color = Color.GREEN

var should_grow: bool = false

# Visual representation
var body_sprites: Array[TextureRect] = []

# Node references
@onready var body_node: Node2D = $Body

signal snake_moved
signal snake_grew

func _ready() -> void:
	var center: Vector2i = Vector2i(GRID_SIZE_X / 2, GRID_SIZE_Y / 2)
	set_body_positions(center, current_direction)
	_update_visual_segments()

func set_body_positions(new_head_position: Vector2i, direction: Vector2i) -> void:	
	body_segments = [new_head_position, new_head_position - direction, new_head_position - direction * 2]
	head_position = body_segments[0]
	tail_position = body_segments[-1]

func next_move() -> Vector2i:
	# If we have a buffered move, use it
	if move_buffer.size() > 0:
		var buffered_move = move_buffer.pop_front()
		return buffered_move
	# Otherwise use requested direction
	return requested_direction

func move() -> bool:
	# Update current direction to requested direction if valid
	if _is_valid_direction_change(current_direction, requested_direction):
		current_direction = requested_direction
	
	var new_head: Vector2i = head_position + current_direction
	
	if _check_collision(new_head):
		return false
		
	body_segments.push_front(new_head)
	if not should_grow:
		body_segments.pop_back()
	should_grow = false
	head_position = body_segments[0]
	tail_position = body_segments[-1]
	_update_visual_segments()
	snake_moved.emit()
	return true

func grow() -> void:
	should_grow = true
	snake_grew.emit()

func _is_valid_direction_change(current: Vector2i, next: Vector2i) -> bool:
	# Can't reverse direction (opposite vectors)
	return current != -next

func _check_collision(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= GRID_SIZE_X or pos.y < 0 or pos.y >= GRID_SIZE_Y:
		return true
	for segment in body_segments:
		if segment == pos:
			return true
	return false

func _relative_direction(a: Vector2i, b:Vector2i) -> int:
	# returns where b is in relation to a
	# where 0 degrees means b is above a
	match b - a:
		Vector2i(0, -1):
			return 0
		Vector2i(1, 0):
			return 90
		Vector2i(0, 1):
			return 180
		Vector2i(-1, 0):
			return 270
	push_error("These two blocks aren't next to each other!")
	assert(false)
	return -1

func _update_visual_segments() -> void:
	# Clear all existing sprites
	for sprite in body_sprites:
		#print(sprite)
		sprite.queue_free()
	body_sprites.clear()
	
	# Create new sprites for each segment
	for i in range(body_segments.size()):
		var segment: TextureRect = TextureRect.new()
		if i == 0:
			segment.texture = preload("res://assets/snake_head.png")
			segment.rotation_degrees = _relative_direction(body_segments[1], body_segments[0])
		elif i == body_segments.size() - 1:
			segment.texture = preload("res://assets/snake_tail.png")
			segment.rotation_degrees = _relative_direction(body_segments[i], body_segments[i-1])
		else:
			var forward_direction = _relative_direction(body_segments[i],body_segments[i - 1])
			var backward_direction = _relative_direction(body_segments[i + 1], body_segments[i])
			if forward_direction == backward_direction:
				segment.texture = preload("res://assets/snake_body.png")
				segment.rotation_degrees = forward_direction
			else:
				segment.texture = preload("res://assets/turning_body.png")
				segment.rotation_degrees = backward_direction
				if (forward_direction - backward_direction + 360) % 360 == 270:
					segment.flip_h = true
		segment.pivot_offset = Vector2(CELL_SIZE / 2, CELL_SIZE / 2)
		segment.modulate = body_color
		body_node.add_child(segment)
		segment.stretch_mode = TextureRect.STRETCH_SCALE
		segment.set_expand_mode(TextureRect.EXPAND_IGNORE_SIZE)
		segment.size = Vector2(CELL_SIZE, CELL_SIZE)
		segment.position = Vector2(body_segments[i].x * CELL_SIZE, body_segments[i].y * CELL_SIZE)
		body_sprites.append(segment)

func get_head_position() -> Vector2i:
	return head_position

func get_tail_position() -> Vector2i:
	return tail_position

func get_body_segments() -> Array[Vector2i]:
	return body_segments.duplicate()

func set_requested_direction(direction: Vector2i) -> void:
	requested_direction = direction

func buffer_move(direction: Vector2i) -> void:
	# Only buffer if we have space and the move is valid
	if move_buffer.size() < 1 and _is_valid_direction_change(current_direction, direction):
		move_buffer.append(direction) 
