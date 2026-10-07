extends Resource
class_name CraftingRecipe

@export var itemToCraft :int = 2 # which item we making?
@export var amountToCraft :int = 1 # how many to craft?

# ingredient list required before the recipe can be used
@export var ingredients :Array[CraftingIngredient] = []

@export var requiresStation :bool = true

# scary c++ stuff
enum stationEnum {NONE = 0, FURNACE = 16, WORKBENCH = 20, GRILL = 46, MAGICINFUSER = 78, SOLDERINGIRON = 94, TRINKETSTATION = 129}
@export var station :stationEnum

enum recipieTypeEnum {BLOCKS,WALLS,TOOL,EQUIP,FOOD,FURNITURE,ELECTRICAL}
@export var recipieType :recipieTypeEnum

# internal recipe index assigned by the c++ layer
var internalID = 0
