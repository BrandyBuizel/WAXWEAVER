extends Resource
class_name Loot

# loot mode
@export_enum("random", "weighted", "all") var rollType: int = 0
# number of rolls
@export var rollCount :int = 1

# all possible drops in this table
@export var table :Array[RollableItem] = []

func getLoot() -> Array[LootItem]:
	var itemArray :Array[LootItem] = []
	
	for i in range(rollCount):
		match rollType:
			0:
				itemArray.append(rollRand())
			1:
				itemArray.append(rollWeight())
			2:
				itemArray += rollAll()
	
	return itemArray

func rollWeight() -> LootItem:
	var item :LootItem = LootItem.new()
	var totalWeight := 0
	for rolleditem in table:
		totalWeight += rolleditem.weight
	
	var rand = randi() % totalWeight # randomly selects from 0 - weight total
	
	var cursor = 0
	for rolleditem in table:
		cursor += rolleditem.weight
		if cursor > rand:
			item.id = rolleditem.id
			item.amount = rollItemAmount(rolleditem)
			return item
	
	# Fallback; should not occur unless weights are invalid.
	print("roll didnt work")
	return item

func rollRand() -> LootItem:
	# random with equal chance
	var r = randi() % table.size()
	var item :LootItem = LootItem.new()
	item.id = table[r].id
	item.amount = rollItemAmount(table[r])
	return item

func rollItemAmount(item:RollableItem) -> int:
	return randi_range(item.amountMin, item.amountMax )

func rollAll() -> Array[LootItem]:
	var a :Array[LootItem]= []
	for rollableItem in table:
		var chance :int= rollableItem.weight
		# weight acts like a % chance x1,000
		if randi() % 1000 < chance:
			var newItem :LootItem = LootItem.new()
			newItem.id = rollableItem.id
			newItem.amount = rollItemAmount(rollableItem)
			a.append(newItem)
			
	return a
