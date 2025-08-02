extends Node2D

# Game state
var game_running: bool = true
var grid: Array[Array] = []
var apples: Array[Vector2i] = []
var apple_scene = preload("res://scenes/Apple.tscn")
var enemy_snake_scene = preload("res://scenes/EnemySnake.tscn")

# References
var player_snake: Snake
var enemy_snakes: Array[Snake] = []

var in_loop: bool = false

# Node references
@onready var grid_node: Node2D = $Grid
@onready var snake_node: Node2D = $Snakes
@onready var apples_node: Node2D = $Apples
@onready var step_timer: Timer = $StepTimer
@onready var camera: Camera2D = $Camera2D
@onready var game_over_ui: Control = $UI/GameOver
@onready var restart_button: Button = $UI/GameOver/PanelContainer/VBoxContainer/RestartButton
@onready var enemies: Node2D = $Enemies

var GRID_CONTENTS = GameConfig.GRID_CONTENTS

func _create_array(x: int, y: int, value) -> Array[Array]:
	var res: Array[Array] = []
	for i in range(x):
		var row: Array = []
		for j in range(y):
			row.append(value)
		res.append(row)
	
	return res

# Validation
func _validate_setup() -> bool:
	if not grid_node or not snake_node or not apples_node:
		push_error("Required nodes not found!")
		return false
	if not step_timer or not camera or not game_over_ui or not restart_button:
		push_error("Required UI nodes not found!")
		return false
	return true

func _ready() -> void:
	# Validate setup
	if not _validate_setup():
		return
	
	# Initialize the grid
	_initialize_grid()
	
	# Spawn player snake
	_spawn_player_snake()
	
	# Spawn enemy snake
	_spawn_enemy_snake()
	
	# Spawn initial apples
	_spawn_apples(GameConfig.APPLE_COUNT)
	
	# Start the game loop
	step_timer.wait_time = GameConfig.STEP_TIME
	step_timer.timeout.connect(_on_step_timer_timeout)
	step_timer.start()
	
	# Connect UI signals
	restart_button.pressed.connect(_on_restart_button_pressed)
	_center_camera()


func _initialize_grid() -> void:
	grid = _create_array(GameConfig.GRID_SIZE_X, GameConfig.GRID_SIZE_Y, GRID_CONTENTS.EMPTY)

	# Create visual grid
	_create_grid_visual()

func _create_grid_visual() -> void:
	for i in range(GameConfig.GRID_SIZE_X):
		for j in range(GameConfig.GRID_SIZE_Y):
			var cell: ColorRect = ColorRect.new()
			cell.size = Vector2(GameConfig.CELL_SIZE, GameConfig.CELL_SIZE)
			cell.position = Vector2(i * GameConfig.CELL_SIZE, j * GameConfig.CELL_SIZE)
			cell.color = GameConfig.GRID_COLOR
			grid_node.add_child(cell)

func _spawn_player_snake() -> void:
	var player_scene = preload("res://scenes/PlayerSnake.tscn")
	player_snake = player_scene.instantiate()
	snake_node.add_child(player_snake)
	
	# Update grid with snake positions
	_update_grid_with_snake()

func _spawn_enemy_snake() -> void:
	var enemy_snake = enemy_snake_scene.instantiate()
	enemy_snakes.append(enemy_snake)
	snake_node.add_child(enemy_snake)
	
	# Set game references for AI
	enemy_snake.set_game_references(grid, player_snake)

func _spawn_apples(count: int) -> void:
	for i in range(count):
		_spawn_single_apple()

func _spawn_single_apple() -> void:
	var attempts: int = 0
	var apple_pos: Vector2i
	
	# Find an empty position
	while attempts < GameConfig.APPLE_SPAWN_ATTEMPTS:
		apple_pos = Vector2i(randi() % GameConfig.GRID_SIZE_X, randi() % GameConfig.GRID_SIZE_Y)
		if grid[apple_pos.x][apple_pos.y] == GRID_CONTENTS.EMPTY:
			break
		attempts += 1
	
	if attempts < GameConfig.APPLE_SPAWN_ATTEMPTS:
		# Place apple on grid
		grid[apple_pos.x][apple_pos.y] = GRID_CONTENTS.APPLE
		apples.append(apple_pos)
		
		# Create visual apple
		var apple = apple_scene.instantiate()
		apple.position = Vector2(apple_pos.x * GameConfig.CELL_SIZE + GameConfig.CELL_SIZE / 2, apple_pos.y * GameConfig.CELL_SIZE + GameConfig.CELL_SIZE / 2)
		apples_node.add_child(apple)

func calculate_inner_parts(current_position: Vector2i, visit_grid: Array[Array]) -> void:
	if not _is_in_grid(current_position):
		return
	if grid[current_position.x][current_position.y] == GRID_CONTENTS.PLAYER_SNAKE:
		return
	if visit_grid[current_position.x][current_position.y]:
		return
	visit_grid[current_position.x][current_position.y] = true
	for step_direction in GameConfig.DIRECTIONS:
		calculate_inner_parts(current_position + step_direction, visit_grid)


func _loop() -> void:
	var visit_grid: Array[Array] = _create_array(GameConfig.GRID_SIZE_X, GameConfig.GRID_SIZE_Y, false)

	for x in range(GameConfig.GRID_SIZE_X):
		calculate_inner_parts(Vector2i(x, 0), visit_grid)
		calculate_inner_parts(Vector2i(x, GameConfig.GRID_SIZE_Y - 1), visit_grid)

	for y in range(GameConfig.GRID_SIZE_Y):
		calculate_inner_parts(Vector2i(0, y), visit_grid)
		calculate_inner_parts(Vector2i(GameConfig.GRID_SIZE_X - 1, y), visit_grid)

	var inner_points: Array[Vector2i] = []
	for x in range(GameConfig.GRID_SIZE_X):
		for y in range(GameConfig.GRID_SIZE_Y):
			if not visit_grid[x][y] and grid[x][y] != GRID_CONTENTS.PLAYER_SNAKE:
				inner_points.append(Vector2i(x, y))

	var possible_corners: Array[Array] = []

	for inner_point in inner_points:
		var current_streak = 0
		for i in range(len(player_snake.body_segments)):
			var dist = inner_point.distance_squared_to(player_snake.body_segments[i])
			if dist == 1:
				if current_streak == 0:
					current_streak += 1
				else:
					possible_corners.append([inner_point, i - current_streak, current_streak])
					break
			elif dist < 4 and current_streak > 0:
				current_streak += 1
			else:
				current_streak = 0

	if len(possible_corners):
		var folded_corner = possible_corners.pick_random()
		player_snake.fold_corner(folded_corner[0], folded_corner[1], folded_corner[2])
	else:
		player_snake.delete_corner()


func _on_step_timer_timeout() -> void:
	if not game_running:
		return
	
	if in_loop:
		_update_grid()
		_update_grid_with_snake()
		_loop()
		if len(player_snake.body_segments) <= 4:
			in_loop = false
		return
	
	player_snake.move()

	for enemy_snake in enemy_snakes:	
		enemy_snake.move()

	# Check for apple collision BEFORE updating grid
	_check_apple_collision()
	
	_check_collisions()
	if game_running:
		_update_grid()

		_update_grid_with_snake()

	# Ensure we have the required number of apples
	while apples.size() < GameConfig.APPLE_COUNT:
		_spawn_single_apple()
	

func _update_grid() -> void:
	for snake in enemy_snakes:
		snake._update_visual_segments()
		
	player_snake._update_visual_segments()

func _check_collisions() -> void:
	var new_grid: Array = []
	for i in range(GameConfig.GRID_SIZE_X):
		var row: Array[Snake] = []
		for j in range(GameConfig.GRID_SIZE_Y):
			row.append(null)
		new_grid.append(row)

	# placing body segments:
	for enemy_snake in enemy_snakes:
		for segment in enemy_snake.get_body_segments().slice(1):
			new_grid[segment.x][segment.y] = enemy_snake
	
	for segment in player_snake.get_body_segments().slice(1):
		new_grid[segment.x][segment.y] = player_snake
	
	var player_head = player_snake.get_head_position()
	if not _is_in_grid(player_head):
		_game_over()
	
	for enemy_snake in enemy_snakes:
		var head = enemy_snake.get_head_position()
		if not _is_in_grid(head):
			_kill_enemy_snake(enemy_snake)
			continue
		if new_grid[head.x][head.y] != null:
			_kill_enemy_snake(enemy_snake)

	if not _is_in_grid(player_head):
		_game_over()
		return

	if new_grid[player_head.x][player_head.y] != null:
		var collided_snake: Snake = new_grid[player_head.x][player_head.y]
		if not collided_snake in enemy_snakes and collided_snake != player_snake:
			return # the head is on a snake that was removed already
		if collided_snake in enemy_snakes:
			if collided_snake.get_head_position() == player_head:
				_kill_enemy_snake(collided_snake)
			elif collided_snake.get_tail_position() == player_head:
				# should eat the snake somehow
				_kill_enemy_snake(collided_snake)
			else:
				_game_over()
		else:
			if player_snake.get_tail_position() == player_head:
				# should eat myself somehow
				in_loop = true
			else:
				_game_over()
		return	


func _kill_enemy_snake(enemy_snake: Snake) -> void:
		enemy_snake.queue_free()
		enemy_snakes.erase(enemy_snake)
		_spawn_enemy_snake()  # Respawn a new enemy snake

func _is_in_grid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GameConfig.GRID_SIZE_X and pos.y >= 0 and pos.y < GameConfig.GRID_SIZE_Y

func _update_grid_with_snake() -> void:
	# Clear previous snake positions
	for i in range(GameConfig.GRID_SIZE_X):
		for j in range(GameConfig.GRID_SIZE_Y):
			if grid[i][j] in [GRID_CONTENTS.ENEMY_SNAKE, GRID_CONTENTS.PLAYER_SNAKE]:
				grid[i][j] = GRID_CONTENTS.EMPTY
	
	# Mark player snake positions
	var body_segments: Array = player_snake.get_body_segments()
	for segment in body_segments:
		grid[segment.x][segment.y] = GRID_CONTENTS.PLAYER_SNAKE
	
	# Mark enemy snake positions
	for enemy_snake in enemy_snakes:
		var enemy_segments: Array = enemy_snake.get_body_segments()
		for segment in enemy_segments:
			grid[segment.x][segment.y] = GRID_CONTENTS.ENEMY_SNAKE

func _check_apple_collision() -> void:
	var snakes = [player_snake] + enemy_snakes
	for snake in snakes:
		var head_pos: Vector2i = snake.get_head_position()
		
		if not _is_in_grid(head_pos):
			return  # Out of bounds, no apple collision

		# Check if head is on an apple
		if grid[head_pos.x][head_pos.y] == GRID_CONTENTS.APPLE:
			# Remove apple from grid and list
			if snake == player_snake:
				grid[head_pos.x][head_pos.y] = GRID_CONTENTS.PLAYER_SNAKE
			else:
				grid[head_pos.x][head_pos.y] = GRID_CONTENTS.ENEMY_SNAKE
			apples.erase(head_pos)
			
			# Remove visual apple - find by grid position
			for apple in apples_node.get_children():
				var apple_grid_pos = Vector2i((apple.position.x - GameConfig.CELL_SIZE / 2) / GameConfig.CELL_SIZE, (apple.position.y - GameConfig.CELL_SIZE / 2) / GameConfig.CELL_SIZE)
				if apple_grid_pos == head_pos:
					apple.queue_free()
					break
			
			# Grow snake
			snake.grow()
		


func _game_over() -> void:
	game_running = false
	step_timer.stop()
	game_over_ui.visible = true
	get_tree().paused = true

func _center_camera() -> void:
	var grid_center = Vector2(GameConfig.GRID_SIZE_X * GameConfig.CELL_SIZE / 2, GameConfig.GRID_SIZE_Y * GameConfig.CELL_SIZE / 2)
	camera.position = grid_center

func _print_positions() -> void:
	var head_pos = player_snake.get_head_position()
	print("Snake head: ", head_pos, " Grid value: ", grid[head_pos.x][head_pos.y])
	
	print("Apples:")
	for apple in apples_node.get_children():
		var apple_grid_pos = Vector2i((apple.position.x - GameConfig.CELL_SIZE / 2) / GameConfig.CELL_SIZE, (apple.position.y - GameConfig.CELL_SIZE / 2) / GameConfig.CELL_SIZE)
		print("  Apple at grid: ", apple_grid_pos, " pixel: ", apple.position)
	
	print("Apple list: ", apples)
	print("---")

func _on_restart_button_pressed() -> void:
	# Reload the scene
	get_tree().paused = false
	get_tree().reload_current_scene()
