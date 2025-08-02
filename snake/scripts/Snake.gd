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

var head_color: Color = Color.DARK_GREEN
var body_color: Color = Color.GREEN


# Visual representation
var body_sprites: Array[ColorRect] = []

# Node references
@onready var body_node: Node2D = $Body

signal snake_moved
signal snake_grew

func _ready() -> void:
	var center: Vector2i = Vector2i(GRID_SIZE_X / 2, GRID_SIZE_Y / 2)
	set_body_positions(center, current_direction)
	_create_visual_segments()

func set_body_positions(new_head_position: Vector2i, direction: Vector2i) -> void:	
	body_segments = [new_head_position, new_head_position - direction, new_head_position - direction * 2]
	head_position = body_segments[0]
	tail_position = body_segments[-1]

func _create_visual_segments() -> void:
	for sprite in body_sprites:
		sprite.queue_free()
	body_sprites.clear()
	for i in range(body_segments.size()):
		var segment: ColorRect = ColorRect.new()
		segment.size = Vector2(CELL_SIZE, CELL_SIZE)
		segment.color = head_color if i == 0 else body_color
		segment.position = Vector2(body_segments[i].x * CELL_SIZE, body_segments[i].y * CELL_SIZE)
		body_node.add_child(segment)
		body_sprites.append(segment)

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

	body_segments.push_front(new_head)
	body_segments.pop_back()
	head_position = body_segments[0]
	tail_position = body_segments[-1]
	snake_moved.emit()
	return true

func grow() -> void:
	# Add a new segment at the current tail position
	body_segments.append(tail_position)
	# Update tail position to the new last segment
	tail_position = body_segments[-1]
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

func _update_visual_segments() -> void:
	# Clear all existing sprites
	for sprite in body_sprites:
		sprite.queue_free()
	body_sprites.clear()
	
	# Create new sprites for each segment
	for i in range(body_segments.size()):
		var segment: ColorRect = ColorRect.new()
		segment.size = Vector2(CELL_SIZE, CELL_SIZE)
		segment.color = body_color if i == 0 else head_color
		segment.position = Vector2(body_segments[i].x * CELL_SIZE, body_segments[i].y * CELL_SIZE)
		body_node.add_child(segment)
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

func fold_corner(inner_point: Vector2i, corner_index: int, corner_length: int) -> void:
	# "folds" a corner, meaning turning corners inside to slowly fill the inner region
	var new_body_segments = body_segments.slice(0, corner_index + 1)
	new_body_segments.append(inner_point)
	new_body_segments += body_segments.slice(corner_index + corner_length)
	#body_segments = body_segments.slice(1)
	body_segments = new_body_segments


func delete_corner() -> void:
	# deletes part of the snake where the snake does a u turn
	for i in range(len(body_segments) - 4):
		if body_segments[i].distance_squared_to(body_segments[i + 3]) == 1:
			body_segments = body_segments.slice(0, i + 1) + body_segments.slice(i + 3)
			return
