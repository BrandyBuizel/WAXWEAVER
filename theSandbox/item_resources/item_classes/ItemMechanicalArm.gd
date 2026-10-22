extends ItemBlock
class_name ItemMechanicalArm
## Hold the arm and right click blocks to choose its targets:
##   first right click  = "take items from" (blue outline)
##   second right click = "place items into" (green outline)
## then place the arm (left click) within 5 blocks of both. Right click an existing arm with the
## two targets chosen to set it up again. Hover an arm with the wrench to see its reach.

func onUse(tileX:int,tileY:int,planetDir:int,planet,lastTile:Vector2):
	var result = super.onUse(tileX,tileY,planetDir,planet,lastTile)
	if result == "success":
		KineticItems.armPlaced(planet,Vector2i(tileX,tileY))
	return result
