extends Snake

# AI variables
var game_grid: Array = []
var player_snake: Snake = null
var direction_chosen: bool = false




func _ready() -> void:
	body_color = Color.PURPLE
	# Start with a random direction
	current_direction = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)].pick_random()
	requested_direction = current_direction
	var new_head_position: Vector2i = Vector2i(GRID_SIZE_X / 4, GRID_SIZE_Y / 4)
	set_body_positions(new_head_position, current_direction)
	 

func _process(_delta: float) -> void:
	if direction_chosen:
		return	
	requested_direction = next_move()
	direction_chosen = true
	
func move() -> bool:
	direction_chosen = false
	return super.move()

func set_game_references(grid: Array, player: Snake) -> void:
	game_grid = grid
	player_snake = player

func next_move() -> Vector2i:	
	# Calculate the best move
	var best_move = _calculate_best_move()
	return best_move

func _calculate_best_move() -> Vector2i:
	var possible_moves = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var valid_moves: Array[Vector2i] = []
	
	# Check each possible move
	for possible_move in possible_moves:
		if _is_valid_direction_change(current_direction, possible_move):
			var new_pos = head_position + possible_move
			if _is_position_safe(new_pos):
				valid_moves.append(possible_move)
	
	# Pick a random valid move
	return valid_moves.pick_random()

func _is_position_safe(pos: Vector2i) -> bool:
	# Check boundaries
	if pos.x < 0 or pos.x >= GameConfig.GRID_SIZE_X or pos.y < 0 or pos.y >= GameConfig.GRID_SIZE_Y:
		return false
	
	# Check if position is occupied by snake body
	for segment in body_segments:
		if segment == pos:
			return false
	
	# Check if position is occupied by player snake
	if player_snake:
		for segment in player_snake.get_body_segments():
			if segment == pos:
				return false
	
	# Check if position is occupied by apple (avoid apples)
	if game_grid.size() > 0 and pos.x < game_grid.size() and pos.y < game_grid[0].size():
		if game_grid[pos.x][pos.y] == 2:  # Apple
			return false
	
	return true 
