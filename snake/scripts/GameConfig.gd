extends RefCounted
class_name GameConfig

# Grid configuration
const GRID_SIZE_X = 40
const GRID_SIZE_Y = 25
const CELL_SIZE = 20

# Game timing
const STEP_TIME = 0.167  # 0.5 / 3 = ~0.167 seconds

# Apple configuration
const APPLE_COUNT = 3
const APPLE_SPAWN_ATTEMPTS = 100

# Snake configuration
const INITIAL_SNAKE_LENGTH = 3

# Colors
const GRID_COLOR = Color(0.2, 0.2, 0.2, 0.3)
const SNAKE_BODY_COLOR = Color.DARK_GREEN
const APPLE_COLOR = Color.RED

# UI
const GAME_OVER_BG_COLOR = Color(0, 0, 0, 0.5) 
