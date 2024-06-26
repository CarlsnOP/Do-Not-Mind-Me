extends CharacterBody2D


const FOV = {
	ENEMY_STATE.PATROLLING: 60.0,
	ENEMY_STATE.CHASING: 120.0,
	ENEMY_STATE.SEARCHING: 100.0
}

const SPEED = {
	ENEMY_STATE.PATROLLING: 60.0,
	ENEMY_STATE.CHASING: 100.0,
	ENEMY_STATE.SEARCHING: 80.0
}


enum ENEMY_STATE { PATROLLING, CHASING, SEARCHING }


@export var patrol_points : NodePath


@onready var sprite_2d = $Sprite2D
@onready var nav_agent = $NavAgent
@onready var label = $Label
@onready var player_detect = $PlayerDetect
@onready var ray_cast_2d = $PlayerDetect/RayCast2D
@onready var warning = $warning
@onready var gasp_sound = $GaspSound
@onready var animation_player = $AnimationPlayer


var _waypoints := []
var _current_wp := 0
var _player_ref: Player
var _state := ENEMY_STATE.PATROLLING


func _ready():
	set_physics_process(false)
	create_wp()
	_player_ref = get_tree().get_first_node_in_group("player")
	call_deferred("set_physics_process", true )

func create_wp() -> void:
	for c in get_node(patrol_points).get_children():
		_waypoints.append(c.global_position)

func _physics_process(delta):
	if Input.is_action_just_pressed("set_target"):
		nav_agent.target_position = get_global_mouse_position()
	
	raycast_to_player()
	update_state()
	update_movement()
	update_navigation()
	set_label()

func get_fov_angle() -> float:
	var direction = global_position.direction_to(_player_ref.global_position)
	var dot_p = direction.dot(velocity.normalized())
	if dot_p >= -1.0 and dot_p <= 1.0:
		return rad_to_deg(acos(dot_p))
	return 0.0

func player_in_fov() -> bool:
	return get_fov_angle() < FOV[_state]

func raycast_to_player() -> void:
	player_detect.look_at(_player_ref.global_position)

func player_detected() -> bool:
	var c = ray_cast_2d.get_collider()
	if c != null:
		return c.is_in_group("player")
	return false

func can_see_player() -> bool:
	return player_in_fov() and player_detected()

func update_navigation() -> void:
	if !nav_agent.is_navigation_finished():
		var next_path_position: Vector2 = nav_agent.get_next_path_position()
		sprite_2d.look_at(next_path_position)
		velocity = global_position.direction_to(next_path_position) * SPEED[_state]
		move_and_slide()

func navigate_wp() -> void:
	if _current_wp >= len(_waypoints):
		_current_wp = 0
	nav_agent.target_position = _waypoints[_current_wp]
	_current_wp += 1

func set_nav_to_player() -> void:
	nav_agent.target_position = _player_ref.global_position

func process_patrolling() -> void:
	if nav_agent.is_navigation_finished():
		navigate_wp()

func process_chasing() -> void:
	set_nav_to_player()

func process_searching() -> void:
	if nav_agent.is_navigation_finished():
		set_state(ENEMY_STATE.PATROLLING)

func update_movement() -> void:
	match _state:
		ENEMY_STATE.PATROLLING:
			process_patrolling()
		ENEMY_STATE.SEARCHING:
			process_searching()
		ENEMY_STATE.CHASING:
			process_chasing()

func set_state(new_state: ENEMY_STATE) -> void:
	if new_state == _state:
		return
	
	if _state == ENEMY_STATE.SEARCHING:
		warning.hide()
	
	if new_state == ENEMY_STATE.SEARCHING:
		warning.show()
	elif new_state == ENEMY_STATE.CHASING:
		SoundManager.play_gasp(gasp_sound)
		animation_player.play("alert")
	elif new_state == ENEMY_STATE.PATROLLING:
		animation_player.play("RESET")
	
	
	_state = new_state

func update_state() -> void:
	var new_state = _state
	var can_see = can_see_player()
	
	if can_see:
		new_state = ENEMY_STATE.CHASING
	elif !can_see and new_state == ENEMY_STATE.CHASING:
		new_state = ENEMY_STATE.SEARCHING
	
	set_state(new_state)

#Debug
func set_label():
	var s = "Done: %s\n" % nav_agent.is_navigation_finished()
	s += "Reached: %s\n" % nav_agent.is_target_reached()
	s += "Target: %s\n" % nav_agent.target_position
	s += "PlayerDetected: %s\n" % player_detected()
	s += "fOV: %.2f %s\n" % [get_fov_angle(), ENEMY_STATE.keys()[_state]]
	s += "Speed: %s %s\n" % [player_in_fov(), SPEED[_state]]
	label.text = s
