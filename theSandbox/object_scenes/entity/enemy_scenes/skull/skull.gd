extends Enemy

@onready var sprite = $Sprite
@onready var ball = preload("res://items/weapons/staffs/firebolt/firebolt.tscn")

var state := 0

var tick :int= 0

func _process(delta):
	match state:
		0:
			hunt(delta)
		1:
			blast(delta)
		
	
	setLight(0.8)
	if getWater() > 0.3:
		$HealthComponent.damagePassive(99,"water")

func blast(delta):
	velocity = lerp( velocity, Vector2.ZERO, 0.04 )
	move_and_slide()
	tick += 1
	if tick > 180:
		var ins = ball.instantiate()
		ins.global_position = global_position
		ins.planet = planet
		ins.velocity = to_local(KineticGear.seenPos(GlobalRef.player.global_position)).normalized() * 450
		ins.hitplayer = true
		get_parent().add_child(ins)
		ins.global_position = global_position
		tick = 0
	
	if to_local(KineticGear.seenPos(GlobalRef.player.global_position)).length() > 200:
		state = 0
		return
	
	$playerCast.target_position = to_local(KineticGear.seenPos(GlobalRef.player.global_position))
	if $playerCast.is_colliding():
		state = 0
	

func hunt(delta):
	var vel = getVelocity()
	
	var targetX = getDirectionTowardsPlayer()
	var targetY = getVERTICALDirectionTowardsPlayer()
	
	var t = Vector2( targetX,targetY ).normalized() * 120.0
	
	var l = 1-pow(2, (-delta/1.0) )
	vel = lerp( vel, t, l )
	
	if $wallcast.is_colliding():
		vel = vel.rotated( (PI/2) + randf_range(-1.0,1.0) )
		vel = vel.normalized() * 100
	
	setVelocity(vel)
	move_and_slide()
	
	sprite.flip_h = vel.x < 0
	sprite.rotation = getWorldRot(self)
	$wallcast.target_position = velocity.normalized() * 6
	
	if to_local(KineticGear.seenPos(GlobalRef.player.global_position)).length() < 200:
		$playerCast.target_position = to_local(KineticGear.seenPos(GlobalRef.player.global_position))
		if !$playerCast.is_colliding():
			state = 1
			tick = 0
