extends CharacterBody2D

@onready var position_label = $UI/PositionLabel
@onready var velocity_line = $Line2D
@onready var latest_checkpoint = position

const SPEED = 400.0
const JUMP_VELOCITY = -550.0
const WALLJUMP_HORIZONTAL = 300.0
const WALLJUMP_BUFFER_TIME = 0.2 # 200ms
const MAX_WALLJUMPS = 2
const MAX_DOUBLEJUMPS = 1
const MAX_DASHES = 1
const WALL_DRAG = 0.25
const COYOTE_TIME := 0.15  # 150ms
const DASH_TIME := 0.15 # 150ms
const DASH_SPEED := SPEED * 4

var coyote_timer := 0.0
var walljump_buffer := 0.0
var walljump_counter := 0
var doublejump_counter := 0
var dash_counter := 0
var dash_timer := 0.0

func _ready():
	latest_checkpoint = global_position
	
	if OS.is_debug_build():
		# Set up the line appearance
		velocity_line.width = 3.0
		velocity_line.default_color = Color.RED
		velocity_line.add_point(Vector2.ZERO)
		velocity_line.add_point(Vector2.ZERO)
		velocity_line.add_point(Vector2.ZERO)

func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("left", "right")
	
	# Start dash
	if dash_counter < MAX_DASHES and Input.is_action_just_pressed("dash") and (direction == sign(get_wall_normal().x) or not is_on_wall()):
		dash_counter += 1
		dash_timer = DASH_TIME

		if direction != 0:
			velocity.x = direction * DASH_SPEED

	# Add the gravity and update coyote time
	if not is_on_floor():
		coyote_timer = max(coyote_timer - delta, 0.0)
		
		if is_on_wall() and velocity.y > 0 and -direction == get_wall_normal().x:
			velocity += get_gravity() * delta * WALL_DRAG
		else:
			velocity += get_gravity() * delta
	else:
		walljump_counter = 0
		dash_counter = 0
		doublejump_counter = 0
		coyote_timer = COYOTE_TIME
	
	# Reset stuff when touching the wall
	if is_on_wall():
		dash_counter = 0

	walljump_buffer = max(walljump_buffer - delta, 0.0)
	dash_timer = max(dash_timer - delta, 0.0)
	
	# Handle jumps and walljumps
	if Input.is_action_pressed("jump"):
		if is_on_wall() and Input.is_action_just_pressed("jump"):
			# Walljump
			if walljump_counter < MAX_WALLJUMPS:
				velocity.x = get_wall_normal().x * WALLJUMP_HORIZONTAL
				velocity.y = JUMP_VELOCITY
				walljump_buffer = WALLJUMP_BUFFER_TIME
				walljump_counter += 1
		elif coyote_timer > 0:
			# Regular jump
			coyote_timer = 0.0
			velocity.y = JUMP_VELOCITY
		elif doublejump_counter < MAX_DOUBLEJUMPS and Input.is_action_just_pressed("jump"):
			# Double jump (coyote time has priority over it)
			doublejump_counter += 1
			velocity.y = JUMP_VELOCITY

	# Handle movement
	if dash_timer <= 0:
		if walljump_buffer <= 0.0 or direction == get_wall_normal().x:
			velocity.x = move_toward(velocity.x, (direction * SPEED), 200) if direction != 0 else move_toward(velocity.x, 0, 32)
		elif walljump_buffer < 0.1:
			velocity.x = move_toward(velocity.x, 0, 32)
	elif dash_timer < 0.05 and sign(velocity.x) != direction:
		velocity.x = move_toward(velocity.x, 0, 300)
	else:
		velocity.y = 0

	move_and_slide()
	
	check_tile_collisions()
	
	if position.y >= 500:
		die()
	
	if OS.is_debug_build():
		velocity_line.set_point_position(0, velocity * 0.5 * Vector2.RIGHT)
		velocity_line.set_point_position(2, velocity * 0.5 * Vector2.DOWN)
		
		position_label.text = "Pos: X=%.1f, Y=%.1f" % [position.x, position.y]

func check_tile_collisions():
	# Check all collisions from the last move_and_slide()
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		
		if collision.get_collider() is TileMapLayer:
			var tilemap_layer = collision.get_collider() as TileMapLayer
			var collision_point = collision.get_position()
			
			# Convert collision point to tile coordinates
			var tile_pos = tilemap_layer.local_to_map(tilemap_layer.to_local(collision_point))
			var source_id = tilemap_layer.get_cell_source_id(tile_pos)
			
			if source_id == 2: # Spike
				die()
			elif source_id == 1: # Checkpoint
				var checkpoint_world_pos = tilemap_layer.to_global(tilemap_layer.map_to_local(tile_pos))
				latest_checkpoint = checkpoint_world_pos + Vector2(-86, -580)
			elif source_id == 4: # Refresh
				print(position)
				walljump_counter = 0
				dash_counter = 0
				doublejump_counter = 0

func die() -> void:
	position = latest_checkpoint
	print("Player hit spikes!")
