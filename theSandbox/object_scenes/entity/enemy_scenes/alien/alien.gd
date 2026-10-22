extends Enemy

@export var HC : HealthComponent
@export var rotationOrigin : Node2D
@export var sprite:Sprite2D
@export var wallWay :RayCast2D
@export var floorRay :RayCast2D

var state = 0 # 0 = passive, 1 = hunting, 2 = stunned

var wanderDir = 0
var animTick = 0
var floatamount = 25.0

func _ready():
	HC.connect("smacked",smack)

func _physics_process(delta):
	match state:
		0:
			wander(delta)
		1:
			hunt(delta)
		2:
			stunned(delta)

func hunt(delta):
	var vel = getVelocity()
	
	var dir = getDirectionTowardsPlayer()
	
	if GlobalRef.player.dead:
		dir *= -1
	
	rotationOrigin.rotation = getQuad(self) * (PI/2)
	
	if floorRay.is_colliding():
		vel.x = lerp(vel.x, dir * 40.0, 0.05 )
	else:
		vel.x = vel.x + (dir * 0.5) * 60 * delta
	
	vel.y += 300 * delta
	
	wallWay.target_position.x = 8 * dir
	wallWay.force_raycast_update()
	if wallWay.is_colliding() and floorRay.is_colliding():
		vel.y = -120
	
	if getPlayerDistance() < 32 and floorRay.is_colliding():
		vel.y = -95
		vel.x = dir * 60
	
	if randi() % 100 == 0 and floorRay.is_colliding():
		vel.y = -95
		vel.x = dir * 60
		
	if getWater() > 0.5:
		vel.y -= floatamount * 60 * delta
	
	setVelocity(vel)
	
	move_and_slide()
	
	animation(dir,delta)

func smack():
	state = 2
	$Hurtbox/CollisionShape2D.call_deferred("set_disabled",false)

func stunned(delta):
	var vel = getVelocity()
	vel.y += 300 * delta
	
	if floorRay.is_colliding():
		vel.x = lerp(vel.x,0.0,0.08)
	
	if getWater() > 0.5:
		vel.y -= floatamount * 60 * delta
	
	setVelocity(vel)
	
	move_and_slide()
	
	rotationOrigin.rotation = getQuad(self) * (PI/2)
	
	animation(0,delta)
	
	if abs(vel.x) < 10:
		state = 1

func wander(delta):
	var vel = getVelocity()
	
	if randi() % 100 == 0:
		wanderDir = (randi() % 3) -1
	
	rotationOrigin.rotation = getQuad(self) * (PI/2)
	
	if floorRay.is_colliding():
		vel.x = lerp(vel.x, wanderDir * 15.0, 0.05 )
	else:
		vel.x = vel.x + (wanderDir * 1) * 60 * delta
	
	vel.y += 300 * delta
	
	wallWay.target_position.x = 8 * wanderDir
	wallWay.force_raycast_update()
	if wallWay.is_colliding() and floorRay.is_colliding():
		vel.y = -120
	
	#if getPlayerDistance() < 36:
	#	state = 1
	
	if getWater() > 0.5:
		vel.y -= floatamount * 60 * delta
	
	setVelocity(vel)
	
	move_and_slide()
	
	animation(wanderDir,delta)

func animation(dir,delta):
	
	if dir != 0:
		sprite.flip_h = dir == -1
		
		match int(animTick):
			0:
				sprite.frame = 1
			8:
				sprite.frame = 0
			16:
				sprite.frame = 2
			24:
				sprite.frame = 0
			32:
				sprite.frame = 1
				animTick = -1
		
		animTick += 1
		
	else:
		sprite.frame = 0
		animTick = 0
	
	if !floorRay.is_colliding():
		sprite.frame = 3
		return
