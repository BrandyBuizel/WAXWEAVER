class_name KineticItems
extends RefCounted
## Item handling for the Create-style machines.
##
## The C++ blocks send command strings through the normal block-change system
## ("kineticPress:32.00", "kineticMill:..", "kineticCrush:..", "kineticMix:..", "kineticFan:..", "kineticDeploy:..",
##  "kineticArm:..", "kineticFunnel", "kineticBasin", "kineticBasinBreak", "kineticStoreBreak").
## BlockData.doBlockAction forwards every command that starts with "kinetic" here (see BlockData_hook.txt).
##
## Machines with an inventory (basin, depot, crushing wheels, deployer) keep it in planet.chestDictionary,
## in the same format as a chest, so the normal chest window can be used as their menu.
##   basin / depot : LEFT two columns = input, RIGHT two columns = output  (middle column unused)
##   crushing wheel: TOP two rows     = input, BOTTOM two rows = output    (middle row unused)

const CHEST_BLOCK :int = 33
const FUNNEL_BLOCK :int = 190
const DEPOT_BLOCK :int = 187
const BASIN_BLOCK :int = 195

## input item id -> [[output id, count], ...]
const PRESS_RECIPES :Dictionary = {
	29: [[7120,1]], # copper bar -> copper sheet
	31: [[7121,1]], # iron bar   -> iron sheet
	30: [[7122,1]], # gold bar   -> gold sheet
}
const MILL_RECIPES :Dictionary = {
	18: [[7130,2]], # copper ore -> 2 copper dust
	27: [[7131,2]], # iron ore   -> 2 iron dust
	24: [[7132,2]], # gold ore   -> 2 gold dust
}
const CRUSH_RECIPES :Dictionary = {
	18: [[7130,3]], # crushing wheels give triple
	27: [[7131,3]],
	24: [[7132,3]],
}
## basin recipes: needs every ingredient in the basin's input slots, gives "out" = [id, count] into the output slots
const MIX_RECIPES :Array = [
	{"in": {29: 1, 30: 1}, "out": [7140, 2]}, # copper bar + gold bar -> 2 brass bars
]

const MIX_STEPS :float = 40.0
const CRUSH_STEPS :float = 18.0
const ARM_STEPS :float = 12.0
const DEPLOY_STEPS :float = 20.0
const ARM_REACH :float = 5.0 # tiles
const REPLACEABLE :Array = [0,1,17,77,82,90,131]

## steps = number of machine ticks (about 15 per second) at 32 RPM, zone = tile (relative to the machine) where items are caught
const MACHINES :Dictionary = {
	"press": {"recipes": PRESS_RECIPES, "steps": 14.0, "zone": [0,1], "radius": 5.0, "push": Vector2(0,0)},
	"mill": {"recipes": MILL_RECIPES, "steps": 30.0, "zone": [0,0], "radius": 6.0, "push": Vector2(0,25)},
}

static var states :Dictionary = {}
static var mixProgress :Dictionary = {}
static var crushProgress :Dictionary = {}
static var armProgress :Dictionary = {}
static var deployProgress :Dictionary = {}

static func run(action:String,x:int,y:int,planet) -> void:
	var parts :PackedStringArray = action.split(":")
	var rpm :float = 32.0
	if parts.size() > 1:
		rpm = float(parts[1])
	match parts[0]:
		"kineticPress":
			machine("press",x,y,planet,rpm)
		"kineticMill":
			machine("mill",x,y,planet,rpm)
		"kineticCrush":
			crush(x,y,planet,rpm)
		"kineticMix":
			mix(x,y,planet,rpm)
		"kineticFan":
			fan(x,y,planet,rpm)
		"kineticDeploy":
			deploy(x,y,planet,rpm)
		"kineticArm":
			arm(x,y,planet,rpm)
		"kineticChute":
			chute(x,y,planet)
		"kineticFunnel":
			funnel(x,y,planet)
		"kineticBasin":
			basin(x,y,planet)
		"kineticBasinBreak", "kineticStoreBreak":
			storeBreak(x,y,planet)

## ground items near a position (planet space)
static func itemsNear(planet,pos:Vector2,radius:float) -> Array:
	var found :Array = []
	for e in planet.entityContainer.get_children():
		if e is GroundItem and !e.tweening and e.position.distance_to(pos) <= radius:
			found.append(e)
	return found

# =====================================================================================
#   press / millstone: catch one item, hold it, work on it, release the result
# =====================================================================================

static func machine(kind:String,x:int,y:int,planet,rpm:float) -> void:
	var def :Dictionary = MACHINES[kind]
	var recipes :Dictionary = def["recipes"]
	var key :Vector2i = Vector2i(x,y)
	var item = null
	
	if states.has(key):
		item = states[key]["item"]
		if !is_instance_valid(item) or item.tweening or item.is_queued_for_deletion():
			states.erase(key)
			item = null
	
	if item == null:
		var zone :Array = def["zone"]
		var center :Vector2 = planet.tileToPos(Vector2(x + zone[0],y + zone[1]))
		for it in itemsNear(planet,center,def["radius"]):
			if !it.heldByMachine and recipes.has(it.itemID):
				item = it
				states[key] = {"item": it, "progress": 0.0}
				break
		if item == null:
			return
	
	# keep it frozen: the item releases itself if we stop talking to it (power loss, machine broken)
	item.heldByMachine = true
	item.holdSilence = 0.0
	
	var st :Dictionary = states[key]
	st["progress"] += rpm / 32.0
	if st["progress"] < def["steps"]:
		return
	st["progress"] = 0.0
	
	for out in recipes[item.itemID]:
		BlockData.spawnItemVelocity(item.position,out[0],planet,def["push"],out[1])
	SoundManager.playSound("blocks/placer",planet.to_global(planet.tileToPos(Vector2(x,y))),0.7,0.1)
	
	item.amount -= 1
	if item.amount <= 0:
		item.heldByMachine = false
		item.pickedByHopper = true
		item.queue_free()
		states.erase(key)
	else:
		item.determineAmount() # the rest of the stack stays held for the next cycle

# =====================================================================================
#   inventories (chest format) and their input / output zones
# =====================================================================================

static func stackSize(id:int) -> int:
	return ItemData.getItem(id).maxStackSize

## slots of the 5x5 chest window that act as input or output
static func zoneSlots(vertical:bool,input:bool) -> Array:
	var out :Array = []
	for i in range(25):
		var idx :int = (i / 5) if vertical else (i % 5)
		if input and idx <= 1:
			out.append(i)
		elif !input and idx >= 3:
			out.append(i)
	return out

static func allSlots() -> Array:
	var a :Array = []
	for i in range(25):
		a.append(i)
	return a

static func isCrusher(id:int) -> bool:
	return id == 193 or id == 194 or id == 198

## true while the player has this exact inventory open. Its contents then live in the inventory slots 53..77
static func isOpen(key:Vector2) -> bool:
	return PlayerData.currentSelectedChest != null and PlayerData.currentSelectedChest == key

## Reads an inventory. If its window is open the live slots are read, so nothing is ever closed on the player.
static func loadStore(planet,key:Vector2) -> Array:
	if isOpen(key):
		var live :Array = []
		for i in range(25):
			var slot = PlayerData.inventory[53 + i]
			live.append([slot[0],slot[1]])
		return live
	if planet.chestDictionary.has(key):
		var s = planet.chestDictionary[key]
		if s is String and s != "" and !s.begins_with("T:"):
			return PlayerData.loadChestString(s)
	return PlayerData.generateEmptyChest()

## Writes an inventory back. An open window is updated in place and stays open.
static func saveStore(planet,key:Vector2,arr:Array) -> void:
	if isOpen(key):
		for i in range(25):
			PlayerData.inventory[53 + i] = [arr[i][0],arr[i][1]]
		PlayerData.saveChestString()
		PlayerData.emit_signal("updateInventory")
		return
	planet.chestDictionary[key] = PlayerData.saveChestFromArray(arr)

## kept for older callers: machines no longer pause while their window is open
static func busy(key:Vector2) -> bool:
	return false

static func addToSlots(arr:Array,slots:Array,id:int,amount:int) -> int: # returns what did not fit
	var left :int = amount
	var ss :int = stackSize(id)
	for i in slots:
		if left <= 0:
			break
		if arr[i][0] == id and arr[i][1] < ss:
			var add :int = min(left,ss - arr[i][1])
			arr[i][1] += add
			left -= add
	for i in slots:
		if left <= 0:
			break
		if arr[i][0] == -1:
			var add :int = min(left,ss)
			arr[i] = [id,add]
			left -= add
	return left

static func capacityFor(arr:Array,slots:Array,id:int) -> int:
	var ss :int = stackSize(id)
	var room :int = 0
	for i in slots:
		if arr[i][0] == -1:
			room += ss
		elif arr[i][0] == id:
			room += ss - arr[i][1]
	return room

static func firstItem(arr:Array,slots:Array) -> int:
	for i in slots:
		if arr[i][0] != -1 and arr[i][1] > 0:
			return arr[i][0]
	return -1

static func countIn(arr:Array,slots:Array,id:int) -> int:
	var total :int = 0
	for i in slots:
		if arr[i][0] == id:
			total += arr[i][1]
	return total

static func removeFrom(arr:Array,slots:Array,id:int,amount:int) -> void:
	var left :int = amount
	for i in slots:
		if left <= 0:
			break
		if arr[i][0] == id:
			var take :int = min(left,arr[i][1])
			arr[i][1] -= take
			left -= take
			if arr[i][1] <= 0:
				arr[i] = [-1,-1]

## the inventory of a basin / depot / crushing wheel pair
static func storeKey(planet,tile:Vector2i,blockID:int) -> Vector2:
	if isCrusher(blockID):
		if isCrusher(planet.DATAC.getTileData(tile.x + 2,tile.y)):
			return Vector2(tile)
		if isCrusher(planet.DATAC.getTileData(tile.x - 2,tile.y)):
			return Vector2(tile.x - 2,tile.y)
	return Vector2(tile)

## hand back everything stored at this position (used when the block is removed)
static func storeBreak(x:int,y:int,planet) -> void:
	var key :Vector2 = Vector2(x,y)
	if isOpen(key):
		PlayerData.closeChest() # saves what is in the window first
	if !planet.chestDictionary.has(key):
		return
	var s = planet.chestDictionary[key]
	planet.chestDictionary.erase(key)
	if !(s is String) or s == "" or s.begins_with("T:"):
		return # an arm's target list, nothing to hand back
	var arr :Array = PlayerData.loadChestString(s)
	var p :Vector2 = planet.tileToPos(key)
	for i in range(25):
		if arr[i][0] != -1 and arr[i][1] > 0:
			BlockData.spawnItemVelocity(p,arr[i][0],planet,Vector2(randf_range(-40,40),-50),arr[i][1])

## a depot lets what is put in on the left come out on the right
static func depotAdvance(planet,key:Vector2) -> void:
	if busy(key):
		return
	var arr :Array = loadStore(planet,key)
	var ins :Array = zoneSlots(false,true)
	var outs :Array = zoneSlots(false,false)
	var changed :bool = false
	for i in ins:
		if arr[i][0] == -1:
			continue
		var left :int = addToSlots(arr,outs,arr[i][0],arr[i][1])
		if left != arr[i][1]:
			changed = true
		if left <= 0:
			arr[i] = [-1,-1]
		else:
			arr[i][1] = left
	if changed:
		saveStore(planet,key,arr)

# =====================================================================================
#   crushing wheels, basin, mixer, funnel
# =====================================================================================

## called by the clockwise wheel of a working pair (both wheels powered, left clockwise, right counter-clockwise)
static func crush(x:int,y:int,planet,rpm:float) -> void:
	var key :Vector2 = Vector2(x,y)
	if busy(key):
		return
	var arr :Array = loadStore(planet,key)
	var ins :Array = zoneSlots(true,true)
	var outs :Array = zoneSlots(true,false)
	var dirty :bool = false
	
	# ore falling into the gap goes into the input slots
	var center :Vector2 = planet.tileToPos(Vector2(x + 1,y))
	for it in itemsNear(planet,center,7.0):
		if it.heldByMachine or it.pickedByHopper or !CRUSH_RECIPES.has(it.itemID):
			continue
		var left :int = addToSlots(arr,ins,it.itemID,it.amount)
		if left != it.amount:
			dirty = true
		if left <= 0:
			it.pickedByHopper = true
			it.queue_free()
		else:
			it.amount = left
			it.determineAmount()
	
	# crush one ore at a time
	var ore :int = -1
	for i in ins:
		if arr[i][0] != -1 and CRUSH_RECIPES.has(arr[i][0]):
			ore = arr[i][0]
			break
	if ore == -1:
		crushProgress.erase(key)
	else:
		var fits :bool = true
		for out in CRUSH_RECIPES[ore]:
			if capacityFor(arr,outs,out[0]) < out[1]:
				fits = false
		if fits:
			crushProgress[key] = crushProgress.get(key,0.0) + rpm / 32.0
			if crushProgress[key] >= CRUSH_STEPS:
				crushProgress.erase(key)
				removeFrom(arr,ins,ore,1)
				for out in CRUSH_RECIPES[ore]:
					addToSlots(arr,outs,out[0],out[1])
				dirty = true
				SoundManager.playSound("blocks/placer",planet.to_global(planet.tileToPos(Vector2(x,y))),0.6,0.1)
	
	if dirty:
		saveStore(planet,key,arr)

## the basin keeps whatever falls into it in its input slots
static func basin(x:int,y:int,planet) -> void:
	var key :Vector2 = Vector2(x,y)
	if busy(key):
		return
	var pos :Vector2 = planet.tileToPos(key)
	var arr = null
	for item in itemsNear(planet,pos,6.0):
		if item.pickedByHopper or item.heldByMachine:
			continue
		if arr == null:
			arr = loadStore(planet,key)
		var left :int = addToSlots(arr,zoneSlots(false,true),item.itemID,item.amount)
		if left != item.amount:
			saveStore(planet,key,arr)
		if left <= 0:
			item.pickedByHopper = true
			item.queue_free()
		elif left != item.amount:
			item.amount = left
			item.determineAmount()

## the mixer sits directly above a basin and mixes what is in its input slots into its output slots
static func mix(x:int,y:int,planet,rpm:float) -> void:
	var key :Vector2i = Vector2i(x,y)
	var basinKey :Vector2 = Vector2(x,y + 1)
	if planet.DATAC.getTileData(x,y + 1) != BASIN_BLOCK or busy(basinKey):
		mixProgress.erase(key)
		return
	var arr :Array = loadStore(planet,basinKey)
	var ins :Array = zoneSlots(false,true)
	var outs :Array = zoneSlots(false,false)
	
	var recipe = null
	for r in MIX_RECIPES:
		var ok :bool = capacityFor(arr,outs,r["out"][0]) >= r["out"][1]
		for id in r["in"]:
			if countIn(arr,ins,id) < r["in"][id]:
				ok = false
		if ok:
			recipe = r
			break
	if recipe == null:
		mixProgress.erase(key)
		return
	
	mixProgress[key] = mixProgress.get(key,0.0) + rpm / 32.0
	if mixProgress[key] < MIX_STEPS:
		return
	mixProgress.erase(key)
	
	for id in recipe["in"]:
		removeFrom(arr,ins,id,recipe["in"][id])
	addToSlots(arr,outs,recipe["out"][0],recipe["out"][1])
	saveStore(planet,basinKey,arr)
	SoundManager.playSound("blocks/placer",planet.to_global(planet.tileToPos(Vector2(x,y))),0.5,0.1)

## a chute touching a chest (above it, or on either side) pulls items out of it and lets them drop down the tube
static func chute(x:int,y:int,planet) -> void:
	var chestPos = null
	for off in [Vector2i(0,-1),Vector2i(-1,0),Vector2i(1,0)]:
		if planet.DATAC.getTileData(x + off.x,y + off.y) == CHEST_BLOCK:
			chestPos = Vector2(x + off.x,y + off.y)
			break
	if chestPos == null:
		return
	
	var arr :Array = loadStore(planet,chestPos)
	var slot :int = -1
	for i in range(25):
		if arr[i][0] != -1 and arr[i][1] > 0:
			slot = i
			break
	if slot == -1:
		return
	
	var id :int = arr[slot][0]
	arr[slot][1] -= 1
	if arr[slot][1] <= 0:
		arr[slot] = [-1,-1]
	saveStore(planet,chestPos,arr)
	
	# the item appears inside the chute and sinks out of the bottom
	BlockData.spawnItemVelocity(planet.tileToPos(Vector2(x,y)),id,planet,Vector2.ZERO,1)

## the funnel pulls items on its tile into the chest it faces
static func funnel(x:int,y:int,planet) -> void:
	var info :int = planet.DATAC.getInfoData(x,y) & 3
	var d :Vector2i = [Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,0)][info]
	var chestPos :Vector2 = Vector2(x + d.x,y + d.y)
	if planet.DATAC.getTileData(int(chestPos.x),int(chestPos.y)) != CHEST_BLOCK:
		return
	var pos :Vector2 = planet.tileToPos(Vector2(x,y))
	for item in itemsNear(planet,pos,9.0):
		if item.pickedByHopper or item.heldByMachine:
			continue
		var left :int = addItemToChest(planet,chestPos,item.itemID,item.amount)
		if left <= 0:
			item.pickedByHopper = true
			item.queue_free()
		elif left != item.amount:
			item.amount = left
			item.determineAmount()

static func addItemToChest(planet,chestPos:Vector2,id:int,amount:int) -> int: # returns how many are left over
	var arr :Array = loadStore(planet,chestPos)
	var left :int = addToSlots(arr,allSlots(),id,amount)
	if left != amount:
		saveStore(planet,chestPos,arr)
	return left

# =====================================================================================
#   encased fan and deployer
# =====================================================================================

const FACE_DIRS :Array = [Vector2(0,1),Vector2(-1,0),Vector2(0,-1),Vector2(1,0)] # info 0..3 = down, left, up, right

## blows loose items along the way it faces (up to 7 tiles), harder at higher RPM
static func fan(x:int,y:int,planet,rpm:float) -> void:
	var d :Vector2 = FACE_DIRS[planet.DATAC.getInfoData(x,y) & 3]
	var perp :Vector2 = Vector2(-d.y,d.x)
	var origin :Vector2 = planet.tileToPos(Vector2(x,y))
	var speed :float = clampf(100.0 * rpm / 32.0,0.0,200.0)
	for e in planet.entityContainer.get_children():
		if !(e is GroundItem) or e.tweening or e.heldByMachine:
			continue
		var rel :Vector2 = e.position - origin
		var along :float = rel.dot(d)
		if along > 3.0 and along < 56.0 and absf(rel.dot(perp)) < 7.0:
			e.velocity = (d * speed).rotated(e.rotSide * (PI/2))

## places the block items stored inside it, one per cycle, on the tile it faces
static func deploy(x:int,y:int,planet,rpm:float) -> void:
	var key :Vector2i = Vector2i(x,y)
	deployProgress[key] = deployProgress.get(key,0.0) + rpm / 32.0
	if deployProgress[key] < DEPLOY_STEPS:
		return
	deployProgress[key] = 0.0
	
	var skey :Vector2 = Vector2(x,y)
	if busy(skey):
		return
	var arr :Array = loadStore(planet,skey)
	var slot :int = -1
	for i in range(25):
		if arr[i][0] != -1 and ItemData.data.has(arr[i][0]):
			var d = ItemData.data[arr[i][0]]
			if d is ItemBlock and !(d is ItemLargeWheel):
				slot = i
				break
	if slot == -1:
		return
	
	var f :Vector2 = FACE_DIRS[planet.DATAC.getInfoData(x,y) & 3]
	var tx :int = x + int(f.x)
	var ty :int = y + int(f.y)
	if !REPLACEABLE.has(planet.DATAC.getTileData(tx,ty)):
		return
	
	planet.editTiles({Vector2i(tx,ty): ItemData.data[arr[slot][0]].blockID},true)
	arr[slot][1] -= 1
	if arr[slot][1] <= 0:
		arr[slot] = [-1,-1]
	saveStore(planet,skey,arr)
	SoundManager.playSound("blocks/placer",planet.to_global(planet.tileToPos(Vector2(x,y))),0.8,0.1)

## right click a deployer: a stack in your hand goes in, an empty hand takes everything back out
static func deployerHand(editBody,tile:Vector2i) -> void:
	var key :Vector2 = Vector2(tile)
	var arr :Array = loadStore(editBody,key)
	var slot :int = PlayerData.selectedSlot
	var held :Array = PlayerData.inventory[slot]
	
	if held[0] == -1:
		var any :bool = false
		for i in range(25):
			if arr[i][0] == -1:
				continue
			var left = PlayerData.addItem(arr[i][0],arr[i][1])
			if left == null or left <= 0:
				arr[i] = [-1,-1]
				any = true
			else:
				arr[i][1] = left
		saveStore(editBody,key,arr)
		say("Took the items back out of the deployer." if any else "The deployer is empty.")
		return
	
	var d = ItemData.data[held[0]]
	if !(d is ItemBlock) or d is ItemLargeWheel:
		say("The deployer can only hold blocks.")
		return
	var rest :int = addToSlots(arr,allSlots(),held[0],held[1])
	saveStore(editBody,key,arr)
	if rest <= 0:
		PlayerData.inventory[slot] = [-1,-1]
	else:
		PlayerData.inventory[slot][1] = rest
	PlayerData.emit_signal("updateInventory")

# =====================================================================================
#   mechanical arm
# =====================================================================================

static func targetKind(id:int) -> String:
	if id >= 184 and id <= 186:
		return "belt"
	if id == FUNNEL_BLOCK:
		return "funnel"
	if id == BASIN_BLOCK:
		return "basin"
	if id == DEPOT_BLOCK:
		return "depot"
	if isCrusher(id):
		return "crusher"
	return ""

static func targetSlots(kind:String,input:bool) -> Array:
	if kind == "funnel":
		return allSlots()
	return zoneSlots(kind == "crusher",input)

## where the inventory behind a target lives
static func targetKey(planet,pos:Vector2i,kind:String) -> Vector2:
	if kind == "funnel":
		var d :Vector2 = FACE_DIRS[planet.DATAC.getInfoData(pos.x,pos.y) & 3]
		return Vector2(pos.x + int(d.x),pos.y + int(d.y))
	return storeKey(planet,pos,planet.DATAC.getTileData(pos.x,pos.y))

static func beltItem(planet,pos:Vector2i):
	var center :Vector2 = planet.tileToPos(Vector2(pos.x,pos.y - 1))
	for it in itemsNear(planet,center,6.0):
		if !it.pickedByHopper:
			return it
	return null

static func peekTake(planet,pos:Vector2i) -> int:
	var kind :String = targetKind(planet.DATAC.getTileData(pos.x,pos.y))
	if kind == "belt":
		var it = beltItem(planet,pos)
		return it.itemID if it != null else -1
	if kind == "":
		return -1
	var key :Vector2 = targetKey(planet,pos,kind)
	if kind == "funnel" and planet.DATAC.getTileData(int(key.x),int(key.y)) != CHEST_BLOCK:
		return -1
	if busy(key):
		return -1
	if kind == "depot":
		depotAdvance(planet,key)
	return firstItem(loadStore(planet,key),targetSlots(kind,false))

static func canPlace(planet,pos:Vector2i,id:int) -> bool:
	var kind :String = targetKind(planet.DATAC.getTileData(pos.x,pos.y))
	if kind == "belt":
		return itemsNear(planet,planet.tileToPos(Vector2(pos.x,pos.y - 1)),7.0).size() < 3
	if kind == "":
		return false
	var key :Vector2 = targetKey(planet,pos,kind)
	if kind == "funnel" and planet.DATAC.getTileData(int(key.x),int(key.y)) != CHEST_BLOCK:
		return false
	if busy(key):
		return false
	return capacityFor(loadStore(planet,key),targetSlots(kind,true),id) >= 1

static func doTake(planet,pos:Vector2i,id:int) -> bool:
	var kind :String = targetKind(planet.DATAC.getTileData(pos.x,pos.y))
	if kind == "belt":
		var it = beltItem(planet,pos)
		if it == null or it.itemID != id:
			return false
		it.amount -= 1
		if it.amount <= 0:
			it.pickedByHopper = true
			it.queue_free()
		else:
			it.determineAmount()
		return true
	var key :Vector2 = targetKey(planet,pos,kind)
	var arr :Array = loadStore(planet,key)
	var slots :Array = targetSlots(kind,false)
	if countIn(arr,slots,id) < 1:
		return false
	removeFrom(arr,slots,id,1)
	saveStore(planet,key,arr)
	return true

static func doPlace(planet,pos:Vector2i,id:int) -> void:
	var kind :String = targetKind(planet.DATAC.getTileData(pos.x,pos.y))
	if kind == "belt":
		BlockData.spawnItemVelocity(planet.tileToPos(Vector2(pos.x,pos.y - 1)),id,planet,Vector2.ZERO,1)
		return
	var key :Vector2 = targetKey(planet,pos,kind)
	var arr :Array = loadStore(planet,key)
	addToSlots(arr,targetSlots(kind,true),id,1)
	saveStore(planet,key,arr)

static func armConfig(planet,pos:Vector2):
	if !planet.chestDictionary.has(pos):
		return null
	var s = planet.chestDictionary[pos]
	if !(s is String) or !s.begins_with("T:"):
		return null
	var parts :PackedStringArray = s.split(";")
	var t :PackedStringArray = parts[0].substr(2).split(",")
	var p :PackedStringArray = parts[1].substr(2).split(",")
	return {"take": Vector2i(int(t[0]),int(t[1])), "place": Vector2i(int(p[0]),int(p[1]))}

static func setArmConfig(planet,pos:Vector2i,take:Vector2i,place:Vector2i) -> void:
	planet.chestDictionary[Vector2(pos)] = "T:%d,%d;P:%d,%d" % [take.x,take.y,place.x,place.y]

## one cycle: take one item from the blue target and put it into the green one
static func arm(x:int,y:int,planet,rpm:float) -> void:
	var cfg = armConfig(planet,Vector2(x,y))
	if cfg == null:
		return
	var key :Vector2i = Vector2i(x,y)
	armProgress[key] = armProgress.get(key,0.0) + rpm / 32.0
	if armProgress[key] < ARM_STEPS:
		return
	armProgress[key] = 0.0
	
	var id :int = peekTake(planet,cfg["take"])
	if id == -1 or !canPlace(planet,cfg["place"],id):
		return
	if doTake(planet,cfg["take"],id):
		doPlace(planet,cfg["place"],id)

# ---------- choosing the two targets with the arm in your hand ----------

static var pendingTake = null    # Vector2i, shown in blue
static var pendingPlace = null   # Vector2i, shown in green
static var pendingNodes :Array = []
static var overlayNodes :Array = []
static var overlayFor = null

static func say(text:String) -> void:
	GlobalRef.sendChat(text)

static func addOutline(body,tile:Vector2i,col:Color,store:Array) -> void:
	var l :Line2D = Line2D.new()
	var c :Vector2 = body.tileToPos(Vector2(tile.x,tile.y))
	l.points = PackedVector2Array([c + Vector2(-4,-4),c + Vector2(4,-4),c + Vector2(4,4),c + Vector2(-4,4),c + Vector2(-4,-4)])
	l.width = 1.0
	l.default_color = col
	l.z_index = 100
	body.add_child(l)
	store.append(l)

static func freeNodes(store:Array) -> void:
	for n in store:
		if is_instance_valid(n):
			n.queue_free()
	store.clear()

static func armClearPending() -> void:
	pendingTake = null
	pendingPlace = null
	freeNodes(pendingNodes)

## right click with the arm in your hand
static func armSelect(editBody,tile:Vector2i) -> void:
	var id :int = editBody.DATAC.getTileData(tile.x,tile.y)
	
	if id == 206 or id == 207:
		if pendingTake != null and pendingPlace != null:
			applyArmConfig(editBody,tile)
		else:
			say("Pick a block to take from (blue) and a block to place into (green) first.")
		return
	
	if targetKind(id) == "":
		say("The arm can only work with belts, funnels, basins, depots and crushing wheels.")
		return
	
	if pendingTake == null or pendingPlace != null:
		armClearPending()
		pendingTake = tile
		addOutline(editBody,tile,Color(0.3,0.6,1.0),pendingNodes)
		say("Take items from this block (blue). Right click another block to choose where they go.")
	else:
		pendingPlace = tile
		addOutline(editBody,tile,Color(0.3,1.0,0.4),pendingNodes)
		say("Place items into this block (green). Now place the arm, or right click an arm to set it up.")

static func applyArmConfig(editBody,armTile:Vector2i) -> void:
	var a :Vector2 = Vector2(armTile)
	if a.distance_to(Vector2(pendingTake)) > ARM_REACH or a.distance_to(Vector2(pendingPlace)) > ARM_REACH:
		say("Out of reach! The arm reaches " + str(int(ARM_REACH)) + " blocks.")
		return
	setArmConfig(editBody,armTile,pendingTake,pendingPlace)
	armClearPending()
	say("Arm set up.")

static func armPlaced(planet,armTile:Vector2i) -> void:
	if pendingTake != null and pendingPlace != null:
		applyArmConfig(planet,armTile)
	elif pendingTake != null:
		say("The arm needs a place target too (right click a second block before placing it).")

## wrench hover on an arm: show its reach and its two targets
static func showArmOverlay(editBody,armTile:Vector2i) -> void:
	if overlayFor == armTile and overlayNodes.size() > 0 and is_instance_valid(overlayNodes[0]):
		return
	clearOverlay()
	overlayFor = armTile
	
	var c :Vector2 = editBody.tileToPos(Vector2(armTile.x,armTile.y))
	var ring :Line2D = Line2D.new()
	var pts :PackedVector2Array = PackedVector2Array()
	for i in range(41):
		var a :float = TAU * i / 40.0
		pts.append(c + Vector2(cos(a),sin(a)) * ARM_REACH * 8.0)
	ring.points = pts
	ring.width = 1.0
	ring.default_color = Color(1.0,1.0,1.0,0.55)
	ring.z_index = 100
	editBody.add_child(ring)
	overlayNodes.append(ring)
	
	var cfg = armConfig(editBody,Vector2(armTile))
	if cfg != null:
		addOutline(editBody,cfg["take"],Color(0.3,0.6,1.0),overlayNodes)
		addOutline(editBody,cfg["place"],Color(0.3,1.0,0.4),overlayNodes)

static func clearOverlay() -> void:
	freeNodes(overlayNodes)
	overlayFor = null

# =====================================================================================
#   machine menus (the chest window with an input and an output side)
# =====================================================================================

static var menuKey = null
static var menuBody = null
static var menuKind :String = ""
static var menuNodes :Array = []
static var menuDimmed :Array = []

## right click without a wrench. Returns true if it handled the block.
static func rightClickBlock(editBody,tile:Vector2i,blockType:int) -> bool:
	if blockType == BASIN_BLOCK or blockType == DEPOT_BLOCK or isCrusher(blockType):
		return openMenu(editBody,tile,blockType)
	if blockType == 204 or blockType == 205:
		deployerHand(editBody,tile)
		return true
	return false

static func openMenu(editBody,tile:Vector2i,blockType:int) -> bool:
	var kind :String = targetKind(blockType)
	var key :Vector2 = storeKey(editBody,tile,blockType)
	if PlayerData.currentSelectedChest != null:
		PlayerData.closeChest()
	menuCleanup()
	if kind == "depot":
		depotAdvance(editBody,key)
	if PlayerData.loadChest(editBody,key):
		menuKey = key
		menuBody = editBody
		menuKind = kind
		decorateMenu(kind == "crusher")
	return true

static func decorateMenu(vertical:bool) -> void:
	var ci = GlobalRef.hotbar.get_node_or_null("ChestInventory")
	if ci == null:
		return
	var font = load("res://zeeg/font/GrapeSoda.ttf")
	var texts :Array = []
	if vertical:
		texts = [["INPUT",Vector2(0,-20)],["OUTPUT",Vector2(0,90)]]
	else:
		texts = [["INPUT",Vector2(0,-20)],["OUTPUT",Vector2(48,-20)]]
	for t in texts:
		var l :Label = Label.new()
		var ls :LabelSettings = LabelSettings.new()
		ls.font = font
		ls.font_size = 16
		ls.font_color = Color(1,1,1)
		ls.outline_size = 5
		ls.outline_color = Color.BLACK
		ls.shadow_size = 3
		ls.shadow_color = Color.BLACK
		l.label_settings = ls
		l.text = t[0]
		l.position = t[1]
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ci.add_child(l)
		menuNodes.append(l)
	
	# the middle column / row does nothing: fade it
	var slots = ci.get_node_or_null("slots")
	if slots != null:
		for s in slots.get_children():
			var i :int = int(s.slotToDisplay) - 53
			var idx :int = (i / 5) if vertical else (i % 5)
			if idx == 2:
				s.modulate = Color(1,1,1,0.3)
				menuDimmed.append(s)

## called every frame: tidies up once the window is closed
static func menuCleanup() -> void:
	if menuKey == null:
		return
	if PlayerData.currentSelectedChest == menuKey:
		return
	freeNodes(menuNodes)
	for s in menuDimmed:
		if is_instance_valid(s):
			s.modulate = Color(1,1,1,1)
	menuDimmed.clear()
	if menuKind == "depot" and is_instance_valid(menuBody):
		depotAdvance(menuBody,menuKey)
	menuKey = null
	menuBody = null
