extends Node

var state = 0
var previous_state = null
var states = {}

@onready var parent = get_parent()

var idleTicks :int = 0
var stateTimer :int = 0

func _ready():
	add_state("intro")
	add_state("idle")
	add_state("beam")
	add_state("status")
	add_state("bullets")
	add_state("teleport")
	add_state("transform")
	
	add_state("idlephase2")
	add_state("beamphase2")
	add_state("statusphase2")
	add_state("gravityphase2")
	add_state("bulletsphase2")
	add_state("dead")
	add_state("leave")
	set_state(states.intro)

func _state_logic(delta):
	
	var pos = parent.position
	
	match state:
		states.idle:
			parent.idlePhase1(delta)
			parent.eyeLookAtPlayer()
			if KineticGear.seenPos(GlobalRef.player.global_position).distance_to(parent.global_position) < 400:
				idleTicks += 1
			else:
				GlobalRef.playerGravityOverride = -1
			ensureplayerisnthiding()
			
		states.beam:
			parent.slowToStop(delta)
			parent.eyeLaser(delta)
		states.bullets:
			parent.slowToStop(delta)
			parent.eyeSpastic(4)
		states.status:
			parent.focusOnPosition(delta)
			parent.eyeSpastic(3)
		states.transform:
			parent.transforming(delta)
			if parent.velocity.y > 0:
				parent.eyeLookAtPlayerPhase2(delta)
			else:
				parent.eyeSpastic(4)
			
		states.idlephase2:
			parent.idlePhase1(delta)
			parent.eyeLookAtPlayerPhase2(delta)
			if KineticGear.seenPos(GlobalRef.player.global_position).distance_to(parent.global_position) < 400:
				idleTicks += 1
			else:
				GlobalRef.playerGravityOverride = -1 # make sure grav is reset is player goes too far away
			
			ensureplayerisnthiding()
			
		states.beamphase2:
			parent.slowToStop(delta)
			parent.eyeLaser(delta)
		states.gravityphase2:
			parent.slowToStop(delta)
			parent.eyeSpastic(3)
		states.statusphase2:
			parent.focusOnPosition(delta)
			parent.eyeSpastic(3)
		states.dead:
			parent.dead(delta)
			parent.eyeDead(delta)
		states.leave:
			parent.dead(delta)
			parent.eyeLookAtPlayer()
			parent.slowToStop(delta)
	
	parent.moveBody(pos,parent.position)
		
func _get_transition(delta):
	
	if state == states.dead:
		return null
	if state == states.leave:
		return null
	if parent.healthComp.health <= 0:
		return states.dead
	if GlobalRef.player.dead:
		return states.leave
	
	match state:
		
		states.intro:
			stateTimer += 1
			if stateTimer > 200:
				stateTimer = 0
				return states.idle
		
		states.idle:
			
			if parent.healthComp.getHealthPercent() < 0.5:
				return states.transform
			
			if idleTicks > 140:
				var r = randi() % 3
				if r == 0:
					return states.beam
				if r == 1:
					return states.bullets
				if r == 2:
					return states.status
		states.beam:
			stateTimer += 1
			if stateTimer > 200:
				stateTimer = 0
				return states.idle
		states.bullets:
			stateTimer += 1
			if stateTimer > 120:
				stateTimer = 0
				return states.idle
		states.status:
			stateTimer += 1
			if stateTimer > 320:
				stateTimer = 0
				return states.idle
		
		states.transform:
			stateTimer += 1
			if stateTimer > 300:
				stateTimer = 0
				return states.idlephase2
		
		
		####### PHASE 2 #########
		states.idlephase2:
			if idleTicks > 120:
				var r = randi() % 6
				if r == 0:
					return states.beamphase2
				if r == 1:
					return states.gravityphase2
				if r == 2:
					return states.statusphase2
				if r == 3:
					return states.beamphase2
				if r == 4:
					return states.statusphase2
				if r == 5:
					return states.beamphase2
		
		states.beamphase2:
			stateTimer += 1
			if stateTimer > 270:
				stateTimer = 0
				return states.idlephase2
		
		states.gravityphase2:
			stateTimer += 1
			if stateTimer > 60:
				stateTimer = 0
				return states.idlephase2
		
		states.statusphase2:
			stateTimer += 1
			if stateTimer > 320:
				stateTimer = 0
				return states.idlephase2
		
	return null

func _enter_state(new_state,old_state):
	match new_state:
		
		states.intro:
			await get_tree().create_timer(0.03).timeout
			var tween = get_tree().create_tween()
			tween.tween_property(parent.fade,"color:a",1.0,1.5)
			await tween.finished
			
			parent.global_position = KineticGear.seenPos(GlobalRef.player.global_position) + Vector2(0,-72)
			
			var tweenout = get_tree().create_tween()
			tweenout.tween_property(parent.fade,"color:a",0.0,1.5)
		
		states.idle:
			parent.focusedPosition = parent.global_position
		states.beam:
			parent.eyeRotate = ((randi() % 2)*2)-1
			await get_tree().create_timer(1.0).timeout
			parent.spawnBeam(parent.eyeRotate,parent.axis.global_position)
		states.bullets:
			parent.spawnBullets(4)
		states.status:
			parent.focusedPosition = GlobalRef.player.position + Vector2(0,-32).rotated(parent.getWorldRot(parent))
			parent.spawnStatusBullets(12,0.5)
		
		states.transform:
			
			parent.hitboxcollider.call_deferred("set_disabled",true)
			
			var tween = get_tree().create_tween()
			tween.tween_property(parent.fade,"color:a",1.0,1.5)
			await tween.finished
			parent.wingScale(1.0)
			GlobalRef.bossEvil = true
			GlobalRef.emit_signal("changeEvilState")
			var tweenout = get_tree().create_tween()
			tweenout.tween_property(parent.fade,"color:a",0.0,1.5)
			await tweenout.finished
			parent.hitboxcollider.call_deferred("set_disabled",false)
		
		states.idlephase2:
			await get_tree().create_timer(0.1).timeout
			var r = randi() % 3
			match r:
				0:
					pass
				1:
					parent.summonLightning()
				2:
					parent.spawnBullets(3)
		
		states.beamphase2:
			
			var tween = get_tree().create_tween()
			tween.tween_property(parent,"split",24,1.0).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			
			var yeah = ((randi() % 2)*2)-1
			await tween.finished
			parent.spawnBeam(yeah,parent.axis.global_position + Vector2(24,0).rotated(parent.getWorldRot(parent)) )
			await get_tree().create_timer(1.2).timeout
			parent.spawnBeam(yeah * -1,parent.axis.global_position + Vector2(-24,0).rotated(parent.getWorldRot(parent)) )
			await get_tree().create_timer(2.3).timeout
			var tween2 = get_tree().create_tween()
			tween2.tween_property(parent,"split",0,0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		states.gravityphase2:
			var yeah = ((randi() % 2)*2)-1
			var quad = parent.getQuad(GlobalRef.player) + yeah
			if quad < 0:
				quad = 3
			elif quad > 3:
				quad = 0
			parent.overrideGravity(quad,16.0)
			SoundManager.playSound("enemy/confuseRay",parent.global_position,0.6, 0.1 )
		
		states.statusphase2:
			parent.focusedPosition = GlobalRef.player.position + Vector2(0,-32).rotated(parent.getWorldRot(parent))
			parent.spawnStatusBullets(24,0.25)
		
		
		states.dead:
			GlobalRef.playerGravityOverride = -1
			parent.bleed.emitting = true
			await get_tree().create_timer(2.0).timeout
			var tween = get_tree().create_tween()
			tween.tween_property(parent.fade,"color:a",1.0,3.0)
			await tween.finished
			parent.disableEvil()
			GlobalRef.playerGravityOverride = -1
			parent.healthComp.forceDrops()
			SoundManager.playSound("enemy/killSquish",parent.global_position,0.5, 0.1 )
			AchievementData.unlockMedal("defeatFinal")
			CreatureData.creatureDeleted(parent)
		
		states.leave:
			
			var tween = get_tree().create_tween()
			tween.tween_property(parent.fade,"color:a",1.0,1.5)
			await tween.finished
			parent.axis.hide()
			parent.disableEvil()
			GlobalRef.playerGravityOverride = -1
			var tweenout = get_tree().create_tween()
			tweenout.tween_property(parent.fade,"color:a",0.0,1.5)
			await tweenout.finished
			CreatureData.creatureDeleted(parent)
		
func _exit_state(old_state, new_state):
	match old_state:
		states.idle:
			idleTicks = 0
		states.idlephase2:
			idleTicks = 0

func ensureplayerisnthiding():
	parent.scanPlayer()
	if parent.haventSeenPlayerTicks > 80:
		parent.haventSeenPlayerTicks = 0
		GlobalRef.player.global_position = parent.global_position
		GlobalRef.player.teleport()


######################################################
############# DONT TOUCH ANY OF THIS #################
######################################################

func _physics_process(delta):
	if state != null:
		_state_logic(delta)
		var transition = _get_transition(delta)
		if transition != null:
			set_state(transition)

func set_state(new_state):
	previous_state = state
	state = new_state
	
	if previous_state != null:
		_exit_state(previous_state,new_state)
	
	if new_state != null:
		_enter_state(new_state,previous_state)

func add_state(state_name):
	states[state_name] = states.size()
