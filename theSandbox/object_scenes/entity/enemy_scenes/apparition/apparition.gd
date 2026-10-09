extends Enemy

@export var HC : HealthComponent
@export var rotationOrigin : Node2D
@export var sprite:Sprite2D
@export var wallWay :RayCast2D
@export var floorRay :RayCast2D

var state = 0 # 0 = idle, 1 = vanished, 2 = appeared and hunting

var wanderDir = 0
var animTick = 0
var floatamount = 25.0

var chaseTicks = 0
var chaseDir = Vector2.ZERO

func _ready():
	HC.connect("smacked",teleport)

func _physics_process(delta):
	match state:
		0:
			idle(delta)
		1:
			vanished(delta)
		2:
			chase(delta)


func idle(delta):
	rotationOrigin.rotation = getQuad(self) * (PI/2)
	if getPlayerDistance() < 48:
		teleport()
	

func teleport():
	state = 1
	$Hurtbox/CollisionShape2D.call_deferred("set_disabled",true)
	var tween = get_tree().create_tween()
	tween.tween_property(sprite,"modulate:a",0.0,0.25)
	await tween.finished
	
	position += Vector2( randi_range(-64,64), randi_range(-64,64) )
	var poog = get_tree().create_tween()
	poog.tween_property(sprite,"modulate:a",0.1,0.25)
	
	chaseDir = getExactDirToPlayer()
	
	chaseTicks = 180
	state = 2
	await poog.finished
	$Hurtbox/CollisionShape2D.call_deferred("set_disabled",false)

func vanished(delta):
	pass

func chase(delta):
	chaseTicks -= 1
	velocity = getExactDirToPlayer() * 25.0
	
	animation(getDirectionTowardsPlayer(),delta)
	
	move_and_slide()
	if chaseTicks <= 0:
		teleport()
	if GlobalRef.player.dead or !GlobalRef.isNight():
		vanishForGood()

func vanishForGood():
	state = 1
	var tween = get_tree().create_tween()
	tween.tween_property(sprite,"modulate:a",0.0,0.25)
	await tween.finished
	queue_free()

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
