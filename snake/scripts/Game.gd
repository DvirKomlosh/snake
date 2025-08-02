extends Node2D

# Game state
var game_running: bool = true
var grid: Array[Array] = []
var apples: Array[Vector2i] = []
var apple_scene = preload("res://scenes/Apple.tscn")
var enemy_snake_scene = preload("res://scenes/EnemySnake.tscn")

# References
var player_snake: Node2D
var enemy_snake: Node2D

# Node references
@onready var grid_node: Node2D = $Grid
@onready var snake_node: Node2D = $Snakes
@onready var apples_node: Node2D = $Apples
@onready var step_timer: Timer = $StepTimer
@onready var camera: Camera2D = $Camera2D
@onready var game_over_ui: Control = $UI/GameOver
@onready var restart_button: Button = $UI/GameOver/PanelContainer/VBoxContainer/RestartButton
@onready var enemies: Node2D = $Enemies

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
	grid.resize(GameConfig.GRID_SIZE_X)
	for i in range(GameConfig.GRID_SIZE_X):
		grid[i] = []
		grid[i].resize(GameConfig.GRID_SIZE_Y)
		for j in range(GameConfig.GRID_SIZE_Y):
			grid[i][j] = 0  # 0 = empty, 1 = snake, 2 = apple
	
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
	enemy_snake = enemy_snake_scene.instantiate()
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
		if grid[apple_pos.x][apple_pos.y] == 0:
			break
		attempts += 1
	
	if attempts < GameConfig.APPLE_SPAWN_ATTEMPTS:
		# Place apple on grid
		grid[apple_pos.x][apple_pos.y] = 2
		apples.append(apple_pos)
		
		# Create visual apple
		var apple = apple_scene.instantiate()
		apple.position = Vector2(apple_pos.x * GameConfig.CELL_SIZE + GameConfig.CELL_SIZE / 2, apple_pos.y * GameConfig.CELL_SIZE + GameConfig.CELL_SIZE / 2)
		apples_node.add_child(apple)

func _on_step_timer_timeout() -> void:
	if not game_running:
		return
	
	# Move the player snake
	if not player_snake.move():
		_game_over()
		return
	
	# Move the enemy snake
	if enemy_snake and not enemy_snake.move():
		# Enemy snake died, respawn it
		enemy_snake.queue_free()
		_spawn_enemy_snake()
	
	# Check for apple collision BEFORE updating grid
	_check_apple_collision()
	
	# Update grid with new snake positions
	_update_grid_with_snake()
	
	# Ensure we have the required number of apples
	while apples.size() < GameConfig.APPLE_COUNT:
		_spawn_single_apple()
	
	# Print positions for debugging
	#_print_positions()

func _update_grid_with_snake() -> void:
	# Clear previous snake positions
	for i in range(GameConfig.GRID_SIZE_X):
		for j in range(GameConfig.GRID_SIZE_Y):
			if grid[i][j] == 1:
				grid[i][j] = 0
	
	# Mark player snake positions
	var body_segments: Array = player_snake.get_body_segments()
	for segment in body_segments:
		grid[segment.x][segment.y] = 1
	
	# Mark enemy snake positions
	if enemy_snake:
		var enemy_segments: Array = enemy_snake.get_body_segments()
		for segment in enemy_segments:
			grid[segment.x][segment.y] = 1

func _check_apple_collision() -> void:
	var head_pos: Vector2i = player_snake.get_head_position()
	
	# Check if head is on an apple
	if grid[head_pos.x][head_pos.y] == 2:
		# Remove apple from grid and list
		grid[head_pos.x][head_pos.y] = 1
		apples.erase(head_pos)
		
		# Remove visual apple - find by grid position
		for apple in apples_node.get_children():
			var apple_grid_pos = Vector2i((apple.position.x - GameConfig.CELL_SIZE / 2) / GameConfig.CELL_SIZE, (apple.position.y - GameConfig.CELL_SIZE / 2) / GameConfig.CELL_SIZE)
			if apple_grid_pos == head_pos:
				apple.queue_free()
				break
		
		# Grow snake
		player_snake.grow()
		
		# Update grid with new tail
		_update_grid_with_snake()

func _game_over() -> void:
	game_running = false
	step_timer.stop()
	game_over_ui.visible = true

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
	get_tree().reload_current_scene() 
