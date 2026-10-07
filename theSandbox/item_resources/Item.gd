extends Resource
class_name Item

@export var itemName : String = ""
@export var subtext : String = ""
@export_multiline var desc : String = ""

@export var texture : Texture

@export var maxStackSize := 99

## FALSE means item can be used continually while mouse is held down
# TRUE means it's only used once
@export var clickToUse := false
## set to TRUE means item can be used even when mouse is far away
@export var infiniteReach := false

var materialIn : Array[int] = []

func onUse(tileX:int,tileY:int,planetDir:int,planet,lastTile:Vector2):
	pass
