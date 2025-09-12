extends RigidBody2D

@export var engine_power = 500
@export var spin_power = 8000
@export var bullet_scene : PackedScene
@export var fire_rate = 0.25

# For screen wrap
var screensize = Vector2.ZERO

# Strength of engine
var thrust = Vector2.ZERO
# Rotate direction of ship
var rotation_dir = 0

var can_shoot = true

enum { INIT, ALIVE, INVULNERABLE, DEAD }
var state = INIT

func _ready() -> void:
	change_state(ALIVE)
	screensize = get_viewport_rect().size
	
func _process(delta: float) -> void:
	get_input()
	
func _physics_process(delta: float) -> void:
	constant_force = thrust
	constant_torque = rotation_dir * spin_power

func _integrate_forces(physics_state: PhysicsDirectBodyState2D) -> void:
	var xform = physics_state.transform
	xform.origin.x = wrapf(xform.origin.x, 0, screensize.x)
	xform.origin.y = wrapf(xform.origin.y, 0, screensize.y)
	physics_state.transform = xform
	
func get_input():
	thrust = Vector2.ZERO
	if state in [DEAD, INIT]:
		return
	if Input.is_action_pressed("thrust"):
		thrust = transform.x * engine_power
	rotation_dir = Input.get_axis("rotate_left", "rotate_right")
	# Shoot
	if Input.is_action_pressed("shoot") and can_shoot:
		shoot()

func shoot():
	if state == INVULNERABLE:
		return
	can_shoot = false
	$GunCooldown.start()
	var b = bullet_scene.instantiate()
	get_tree().root.add_child(b)
	# Give start position to bullet scene
	b.start($Muzzle.global_transform)

func change_state(new_state):
	match new_state:
		# Set CollisionShape2D state
		INIT, INVULNERABLE, DEAD:
			$CollisionShape2D.set_deferred("disabled", true)
		ALIVE:
			$CollisionShape2D.set_deferred("disabled", false)
	state = new_state
		

func _on_gun_cooldown_timeout() -> void:
	can_shoot = true
