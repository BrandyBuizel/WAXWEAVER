extends Item
class_name ItemWrench

## Create-style wrench.
## LEFT CLICK  : picks up a machine/electrical block straight into your inventory (no drop on the ground)
## RIGHT CLICK : rotates the block (handled in rightClicker.gd -> wrenchRotate)

## block IDs the wrench is allowed to pick up (never terrain or chests)
const PICKUP_BLOCKS :Array[int] = [
	91,  # wire
	95,  # electric lamp
	97,  # lever
	98,  # observer
	99,  # clock
	100, # resistor/repeater
	101, # drill
	102, # spitter
	103, # extender
	104, # placer
	105, # conveyor belt
	152, # info scanner
	153, # fireball trap
	160, # number scanner
	161, # sucker
	169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, # kinetic blocks
	182, 183, 184, 185, 186, 187, 188, 189, 190, # large wheel, belt, depot, press, funnel
	191, 192, 193, 194, 195, 196, 197, # millstone, crushing wheel, basin, mixer
	198, 199, 200, 201, 202, 203, 204, 205, 206, 207, # ccw crushing wheel, fan, chute, saw, deployer, arm
]

func onUse(tileX:int,tileY:int,planetDir:int,planet,lastTile:Vector2):
	
	if lastTile == Vector2(tileX,tileY):
		return
	
	var blockID :int = planet.DATAC.getTileData(tileX,tileY)
	if !PICKUP_BLOCKS.has(blockID):
		return
	
	var dropID :int = BlockData.theChunker.getBlockDictionary(blockID)["itemToDrop"]
	if dropID < 0 or !ItemData.data.has(dropID):
		return
	
	if [187,193,194,195,198,204,205,206,207].has(blockID):
		KineticItems.storeBreak(tileX,tileY,planet) # hand back what was stored inside / forget the arm's targets
	
	if blockID == 182 or blockID == 183:
		# the large wheel is 9 tiles: remove all of them and give back ONE wheel
		var piece :int = planet.DATAC.getInfoData(tileX,tileY) & 15
		var cx :int = tileX - (piece % 3 - 1)
		var cy :int = tileY - (piece / 3 - 1)
		var edits :Dictionary = {}
		for iy in range(-1,2):
			for ix in range(-1,2):
				var id :int = planet.DATAC.getTileData(cx + ix,cy + iy)
				if id == 182 or id == 183:
					edits[Vector2i(cx + ix,cy + iy)] = 0
		planet.editTiles(edits)
	else:
		# 0 = remove the block without spawning a drop
		planet.editTiles( {Vector2i(tileX,tileY):0} )
	
	# straight into the inventory, only drops on the ground if the inventory is full
	var leftover = PlayerData.addItem(dropID,1)
	if leftover != null and leftover > 0:
		BlockData.spawnItemRaw(tileX,tileY,dropID,planet)
	
	SoundManager.playSound("interacts/door",planet.to_global(planet.tileToPos(Vector2(tileX,tileY))),1.6,0.1)
