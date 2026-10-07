extends CharacterBody2D
class_name Ship

@onready var DATAC = $PLANETDATA
var chunkScene = preload("res://world_scenes/ship/shipChunk/shipChunk.tscn")
@onready var chunkContainer = $ChunkContainer
@onready var entityContainer = $EntityContainer
var chunkArray2D :Array= []
var allChunks :Array = []

var SIZEINCHUNKS :int= 4

var tick = 0

var targetRot = 0

var chestDictionary :Dictionary= {}

var spaceFlightMaxSpeed :float= 2000.0
var wasOnPlanet = false

func _ready():
	generateEmptyArray()
	print("Successfully made array")
	createChunks()
	print("Successfully created Chunks")

func _process(delta):
	
	var active = true
	if !is_instance_valid(GlobalRef.player):
		active = false # disable if player doesnt exist
	if GlobalRef.player.shipOn != self:
		active = false # disable if not on ship/on wrong ship
	if GlobalRef.player.movementState != 1:
		active = false # disable if not sitting
	
	var dir = Vector2.ZERO
	dir.x = int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	dir.y = int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	
	if !active:
		dir = Vector2.ZERO
	
	var vel :Vector2= velocity.rotated( -rotation )
	var onplanet = get_parent().is_in_group("planet")
	
	if onplanet:
		wasOnPlanet = true
		if dir.y == 0:
			vel.y += 500.0 * delta
		else:
			vel.y = lerp( vel.y, dir.y * 200.0, 0.1 )
		
		var p = get_parent().get_parent()
		var pos = p.posToTile(position)
		if pos != null: 
			if abs( p.DATAC.getWaterData(pos.x,pos.y) ) > 0.5:
				vel.y = lerp( vel.y, -100.0, 0.1 )
		
		if !is_on_floor():
			vel.x = lerp( vel.x, dir.x * 200.0, 0.1 )
			chunkContainer.rotation = lerp(chunkContainer.rotation,0.05*dir.x,0.2)
		else:
			vel.x = lerp( vel.x, 0.0, 0.4 )
			chunkContainer.rotation = 0.0
	else:
		
		if wasOnPlanet:
			spaceFlightMaxSpeed = 300.0
			wasOnPlanet = false
			vel *= 1.2
		
		vel += dir * 10.0
		print(vel.length())
		if vel.length() > spaceFlightMaxSpeed:
			vel = vel.normalized() * spaceFlightMaxSpeed
		if !active:
			spaceFlightMaxSpeed = lerp( spaceFlightMaxSpeed, 60.0,0.05 )
		else:
			spaceFlightMaxSpeed = lerp( spaceFlightMaxSpeed, 2000.0,0.5 )
	
	# if dir == Vector2.ZERO:
	# velocity = Vector2.ZERO
	
	velocity = vel.rotated(rotation)
	
	var glo = global_position
	
	move_and_slide()
	
	velocity = get_real_velocity()
	
	var prevRot = rotation
	
	if get_parent().is_in_group("planet"):
		var angle1 = Vector2(1,1)
		var angle2 = Vector2(-1,1)
		
		var dot1 = int(position.dot(angle1) >= 0)
		var dot2 = int(position.dot(angle2) > 0) * 2
		
		targetRot = [0,1,3,2][dot1 + dot2]
		rotation = lerp_angle(rotation,targetRot*(PI/2),0.04)
		# elif active:
		#var rotDir = int(Input.is_action_pressed("rotateShipRight")) - int(Input.is_action_pressed("rotateShipLeft"))
		#rotate(rotDir * 1.0 * delta)
	
	else:
		rotation = lerp_angle(rotation,0.0,0.008)
	
	if GlobalRef.player.shipOn == self:
		var rotDif = prevRot - rotation
		var dif = (global_position - glo)
		GlobalRef.player.position += dif
		#GlobalRef.player.camera.position -= dif
		
		var what = to_local(GlobalRef.player.global_position).rotated(-rotDif)
		GlobalRef.player.global_position = to_global(what)
		GlobalRef.player.scrollBackgrounds(velocity,delta)
		GlobalRef.player.ensureCamPosition()
	
	# stabilize position
	#chunkContainer.global_position.x = int(global_position.x)
	#chunkContainer.global_position.y = int(global_position.y)
	 
func generateEmptyArray():
	
	var centerPoint = Vector2(SIZEINCHUNKS*4,SIZEINCHUNKS*4) - Vector2(0.5,0.5)
	var s := SIZEINCHUNKS * 8
	
	DATAC.createEmptyArrays(s,centerPoint)
	
	var testDick = {
		Vector2(13,18):13,Vector2(14,18):13,Vector2(15,18):13,
		Vector2(16,18):13,Vector2(17,18):13,Vector2(18,18):13,
		Vector2(13,17):13,Vector2(18,17):13,
	}
	
	for x in range(s):
		for y in range(s):
			# c++
			if testDick.has(Vector2(x,y)):
				DATAC.setTileData(x,y,testDick[Vector2(x,y)])
			else:
				DATAC.setTileData(x,y,0)
			DATAC.setBGData(x,y,0)
			if x >= 13 and x <= 18 and y >= 15 and y <= 18:
				DATAC.setBGData(x,y,13)
			DATAC.setLightData(x,y,0.0)
			DATAC.setTimeData(x,y,0)
			DATAC.setWaterData(x,y,0.0)
			DATAC.setPositionLookup(x,y,0)

func createChunks():
	chunkArray2D = []
	for x in range(SIZEINCHUNKS):
		chunkArray2D.append([])
		for y in range(SIZEINCHUNKS):
			var ins = chunkScene.instantiate()
			ins.pos = Vector2(x,y)
			ins.ship = self
			chunkArray2D[x].append(ins)
			allChunks.append(ins)
			chunkContainer.add_child(ins)
			

########################################################################
########################## CHUNK SIMULATION ############################
########################################################################

func _physics_process(delta):
	tick += 1
	DATAC.setGlobalTick(GlobalRef.globalTick)

	for chunk in allChunks:
		if tick % 4 != chunk.id4:
			continue
		
		var changesArray = chunk.tickUpdate()
		var committedChanges = {}
		
		for d in changesArray:
			if d is bool:
				if d:
					chunk.drawLiquid()
				continue
			var toss = false
			for i in d.keys():
				if committedChanges.has(i):
					toss = true
			if !toss:
				for i in d.keys():
					committedChanges[i] = d[i]
		
		editTiles(committedChanges)
	
	if get_parent().is_in_group("planet"):
		# simulate light attempt
		var p = get_parent().get_parent()
		var pos = p.posToTile(position)
		if pos == null: 
			return
		DATAC.copyLightFromShip( p.DATAC, int(pos.x),int(pos.y),targetRot, BlockData.theChunker.returnLookup())

func editTiles(changeCommit):
	var chunksToUpdate = []
	
	for change in changeCommit.keys():
		var c = changeCommit[change]
		match c:
			-1:
				var save:int = DATAC.getTileData(change.x,change.y)
				DATAC.setTileData(change.x,change.y,0)
				BlockData.breakBlock(change.x,change.y,self,save,DATAC.getInfoData(change.x,change.y))
				DATAC.setInfoData(change.x,change.y,0)
				
				if chestDictionary.has(Vector2(change.x,change.y)): # clear chest
					var p = Vector2(change.x,change.y)
					PlayerData.dropChestContainer(self,p,chestDictionary[p])
					chestDictionary.erase(p)
				
			0:
				DATAC.setTileData(change.x,change.y,0)
				DATAC.setTimeData(change.x,change.y,GlobalRef.globalTick)
				DATAC.setInfoData(change.x,change.y,0)
			-99999:
				var save:int = DATAC.getBGData(change.x,change.y)
				DATAC.setBGData(change.x,change.y,0)
				BlockData.breakWall(change.x,change.y,self,save)
			_: #Default
				if c < -1:
					DATAC.setBGData(change.x,change.y,abs(c))
				else:
					DATAC.setTileData(change.x,change.y,c)
				DATAC.setTimeData(change.x,change.y,GlobalRef.globalTick)
		
		
		
		var foundChunk = chunkArray2D[clamp(change.x/8,0,SIZEINCHUNKS-1)][clamp(change.y/8,0,SIZEINCHUNKS-1)]
		if !chunksToUpdate.has(foundChunk):
			chunksToUpdate.append(foundChunk)
		
		#Theres gotta be a way to clean this up
		if int(change.x) % 8 == 0 and change.x > 8:
			var foundChunkLEFT = chunkArray2D[(change.x/8)-1][change.y/8]
			if !chunksToUpdate.has(foundChunkLEFT):
				chunksToUpdate.append(foundChunkLEFT)
		elif int(change.x) % 8 == 7 and change.x < (SIZEINCHUNKS*8)-8:
			var foundChunkRIGHT = chunkArray2D[(change.x/8)+1][change.y/8]
			if !chunksToUpdate.has(foundChunkRIGHT):
				chunksToUpdate.append(foundChunkRIGHT)
			
		if int(change.y) % 8 == 0 and change.y > 8:
			var foundChunkUP = chunkArray2D[change.x/8][(change.y/8)-1]
			if !chunksToUpdate.has(foundChunkUP):
				chunksToUpdate.append(foundChunkUP)
		elif int(change.y) % 8 == 7 and change.y < (SIZEINCHUNKS*8)-8:
			var foundChunkDOWN = chunkArray2D[change.x/8][(change.y/8)+1]
			if !chunksToUpdate.has(foundChunkDOWN):
				chunksToUpdate.append(foundChunkDOWN)
	
	for chunk in chunksToUpdate:
		chunk.drawData()

#################################################################
############################# MATH #############################
##################################################################

func posToTile(pos): # uses relative local position
	var r := SIZEINCHUNKS * 32
	if pos.x != clamp(pos.x,-r,r):
		return null # returns null if outside boundaries
	if pos.y != clamp(pos.y,-r,r):
		return null # returns null if outside boundaries
	
	var relativePos = pos + Vector2(r,r)
	
	return Vector2(int(relativePos.x)/8,int(relativePos.y)/8)

func tileToPos(pos):
	var r := SIZEINCHUNKS * 32
	
	return (pos * 8) + Vector2(4,4) - Vector2(r,r)

func tileToPosRotated(pos):
	var r := SIZEINCHUNKS * 32
	
	var newPos = (pos * 8) + Vector2(4,4) - Vector2(r,r)
	
	return newPos.rotated(rotation)

func getBlockPosition(x,y):
	return 0
