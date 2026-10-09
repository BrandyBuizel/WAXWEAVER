extends Area2D
class_name Hitbox

@export var healthComponent :HealthComponent = null

@export var enemyBox :bool = true
@export var invincTime :float = 0.0

@export var colliderShape :CollisionShape2D = null

var collectedIDs = []

var invincible = false

func _ready():
	if healthComponent == null:
		#print("Error, entity has no health component")
		#queue_free()
		pass
	if colliderShape == null:
		print("Error, entity has no hitbox collision shape")
		queue_free()

func _on_area_entered(area):
	#check for invalid area
	if !area is Hurtbox:
		return
	if enemyBox == area.enemyBox:
		return
	if collectedIDs.has(area.id) and enemyBox:
		return
	if invincible:
		return
		
	# is now valid hurtbox
	
	# get dir for knockback
	var dir = global_position - area.global_position
	
	collectedIDs.append(area.id)
	
	var hitCrit :bool= false
	var knock = area.knockback
	
	if enemyBox:
		if Stats.getCriticalStrikeChance() >= (randi() % 100) + 1: # rolls from 1 - 100
			hitCrit = true
			knock *= 1.4
		
	healthComponent.damage(area.damage,area,hitCrit,area.enemyName,area.damageType)
	healthComponent.dealKnockback(120.0,dir,knock)
	
	for effect in area.statusInflictors:
		var chance :int= (randi() % 100) + 1
		if chance <= effect.chance:
			healthComponent.inflictStatus( effect.effectName, effect.seconds )
	
	area.hasHit()
	
	colliderShape.call_deferred("set_disabled",true)
	invincible = true
	await get_tree().process_frame
	
	if invincTime > 0.0:
		await get_tree().create_timer(invincTime).timeout
	colliderShape.call_deferred("set_disabled",false)
	invincible = false
	
	if collectedIDs.size() > 3:
		collectedIDs.remove_at(0)
	
