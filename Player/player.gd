extends RigidBody2D

signal lives_changed
signal dead
signal shield_changed

@export var engine_power = 500
@export var spin_power = 8000
@export var bullet_scene : PackedScene
@export var fire_rate = 0.25

@export var max_shield = 100.0
@export var shield_regen = 5.0



var reset_pos = false

var lives = 0: set = set_lives
func set_lives(value):
	lives = value
	lives_changed.emit(lives)
	if lives <= 0:
		change_state(DEAD)
	else:
		change_state(INVULNERABLE)
		shield = max_shield
		
# For screen wrap
var screensize = Vector2.ZERO

# Strength of engine
var thrust = Vector2.ZERO
# Rotate direction of ship
var rotation_dir = 0

var can_shoot = true

enum { INIT, ALIVE, INVULNERABLE, DEAD }
var state = INIT

var shield = 0: set = set_shield

func set_shield(value):
	value = min(value, max_shield)
	shield = value
	shield_changed.emit(shield / max_shield)
	if shield <= 0:
		lives -=1
		explode()
	

func _ready() -> void:
	change_state(ALIVE)
	screensize = get_viewport_rect().size
	
func _process(delta: float) -> void:
	get_input()
	shield += shield_regen * delta

func reset():
	reset_pos = true
	$Sprite2D.show()
	lives = 3
	change_state(ALIVE)

func _physics_process(delta: float) -> void:
	constant_force = thrust
	constant_torque = rotation_dir * spin_power

func _integrate_forces(physics_state: PhysicsDirectBodyState2D) -> void:
	
	if reset_pos:
		physics_state.transform.origin = screensize/2
		reset_pos = false
	
	var xform = physics_state.transform
	xform.origin.x = wrapf(xform.origin.x, 0, screensize.x)
	xform.origin.y = wrapf(xform.origin.y, 0, screensize.y)
	physics_state.transform = xform
	
func get_input():
	thrust = Vector2.ZERO
	$Exhaust.emitting = false
	if state in [DEAD, INIT]:
		return
	if Input.is_action_pressed("thrust"):
		thrust = transform.x * engine_power
		if not $EngineSound.playing:
			$EngineSound.play()
		$Exhaust.emitting = true
	else:
		$EngineSound.stop()
		
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
	$LaserSound.play()

func change_state(new_state):
	match new_state:
		# Set CollisionShape2D state
		INIT:
			$CollisionShape2D.set_deferred("disabled", true)
			$Sprite2D.modulate.a = 0.5
		INVULNERABLE:
			$CollisionShape2D.set_deferred("disabled", true)
			$Sprite2D.modulate.a = 0.5
			$InvulnerabilityTimer.start()
		DEAD:
			$CollisionShape2D.set_deferred("disabled", true)
			$Sprite2D.hide()
			linear_velocity = Vector2.ZERO
			dead.emit()
			$EngineSound.stop()
		ALIVE:
			$CollisionShape2D.set_deferred("disabled", false)
			$Sprite2D.modulate.a = 1
	state = new_state
		

func _on_gun_cooldown_timeout() -> void:
	can_shoot = true

func _on_invulnerability_timer_timeout() -> void:
	change_state(ALIVE)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("rocks"):
		shield -= body.size * 25
		body.explode()
func explode():
	$Explosion.show()
	$Explosion/AnimationPlayer.play("explosion")
	await $Explosion/AnimationPlayer.animation_finished
	$Explosion.hide()
