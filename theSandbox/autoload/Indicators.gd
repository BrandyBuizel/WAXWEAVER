extends Node2D

@onready var damageIndicator = preload("res://ui_scenes/damageIcons/damage_indicator.tscn")
@onready var itemIndicator = preload("res://ui_scenes/damageIcons/item_indicator.tscn")

func damnPopup(amount:int,pos:Vector2,type:String="normal"):
	var ins = damageIndicator.instantiate()
	ins.global_position = pos
	ins.number = amount
	ins.type = type
	add_child(ins)

func itemPopup(itemName:String,amount:int,pos:Vector2):
	var ins = itemIndicator.instantiate()
	ins.global_position = pos
	ins.text = itemName
	if amount > 1:
		ins.text = itemName + " x " + str(amount)
	add_child(ins)

func moneyPopup(amount:int,pos:Vector2):
	if amount < 1:
		return
	var ins = itemIndicator.instantiate()
	ins.global_position = pos
	ins.text = ""
	ins.money = amount
	add_child(ins)
