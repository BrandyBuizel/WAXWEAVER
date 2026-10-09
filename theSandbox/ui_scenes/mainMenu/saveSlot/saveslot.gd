extends Container

@export var saveFile :String = "save1"

@onready var helmetSpr = $info/playermodel/armorhead
@onready var legsSpr = $info/playermodel/armorLeg
@onready var chestSpr = $info/playermodel/armorBody

@onready var menu = get_parent().get_parent().get_parent().get_parent()

func _ready():
	setData()

func setData():
	var gameData = Saving.read_save(saveFile)
	if gameData == null:
		$emptyslot.show()
		$info.hide()
		$createNew.show()
		return
	else:
		$emptyslot.hide()
		$info.show()
		$createNew.hide()
	
	var ticks :int= gameData["playtime"]
	var seconds = ticks/15 # sets to seconds
	var minutes = seconds / 60
	$info/h/playtime.text = str( minutes / 60 ) + "h " + str(minutes%60) + "m"
	
	if gameData.has("worldname"):
		$info/h/worldName.text = gameData["worldname"]
		$info/h/worldName.text = $info/h/worldName.text.left(20)
	else:
		$info/h/worldName.text = saveFile
	
	changeArmor(gameData)
	
	if OS.has_feature("web"): # enable download button
		$info/download.show()
		$info/delete.position.x -= 16
	
	
func setAllFrames(frame:int):
	for child in $info/playermodel.get_children():
		child.frame = frame

func changeArmor(gameData:Dictionary):
	
	var inv = bytes_to_var(gameData["playerInventory"].hex_decode())
	
	var helmet = ItemData.getItem(inv[40][0])
	var chest = ItemData.getItem(inv[41][0])
	var legs = ItemData.getItem(inv[42][0])
	
	var vanityHelmet = ItemData.getItem(inv[50][0])
	var vanityChest = ItemData.getItem(inv[51][0])
	var vanityLegs = ItemData.getItem(inv[52][0])
	
	# check for main armor
	if helmet is ItemArmorHelmet:
		helmetSpr.texture =  helmet.armorTexture
	else:
		helmetSpr.texture = null
	if chest is ItemArmorChest:
		chestSpr.texture =  chest.armorTexture
	else:
		chestSpr.texture = null
	if legs is ItemArmorLegs:
		legsSpr.texture =  legs.armorTexture
	else:
		legsSpr.texture = null
	
	# check for vanity
	if vanityHelmet is ItemArmorHelmet:
		helmetSpr.texture =  vanityHelmet.armorTexture

	if vanityChest is ItemArmorChest:
		chestSpr.texture =  vanityChest.armorTexture

	if vanityLegs is ItemArmorLegs:
		legsSpr.texture =  vanityLegs.armorTexture

func _on_text_button_pressed():
	Saving.loadedFile = saveFile
	get_tree().change_scene_to_file("res://world_scenes/system/system.tscn")

func _on_create_pressed():
	menu.createNewSave(self)

func createNewWorld():
	Saving.loadedFile = saveFile
	
	# be sure to reset all data
	GlobalRef.playerSpawnPlanet = null
	GlobalRef.playerSpawn = null
	GlobalRef.clearEverything()
	PlayerData.initializeInventory()
	
	get_tree().change_scene_to_file("res://world_scenes/system/system.tscn")

func _on_delete_pressed():
	menu.areyousuredelete(self)

func deleteSave():
	Saving.clearSave(saveFile)	
	
	$emptyslot.show()
	$info.hide()
	$createNew.show()

func _on_download_pressed():
	Saving.downloadsave(saveFile)

func _on_rename_world_pressed():
	menu.renameWorld( $info/h/worldName.text,saveFile )
