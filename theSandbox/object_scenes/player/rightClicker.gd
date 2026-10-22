extends Node2D

@onready var parent = get_parent()

# --- Create-style kinetic helpers: SU goggles tooltip, wrench rotation, creative motor panel ---
var gogglesPanel :VBoxContainer   # holds the title box and the info box, like the inventory item preview
var gogglesTitle :Label
var gogglesContent :VBoxContainer
var gogglesInfoBox :PanelContainer
var tipFont :Font = null
var gogglesSig :String = ""
var motorPanel = null

const GREY := Color(0.72,0.72,0.75)
const WHITE := Color(1,1,1)
const GREEN := Color(0.35,1.0,0.4)
const YELLOW := Color(1.0,0.85,0.25)
const RED := Color(1.0,0.35,0.3)
const CYAN := Color(0.3,0.95,1.0)
const BLUE := Color(0.45,0.75,1.0)
const MAGENTA := Color(1.0,0.45,1.0)
const ORANGE := Color(1.0,0.6,0.2)

func _ready():
	var layer = CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	
	tipFont = load("res://zeeg/font/GrapeSoda.ttf")
	
	# same look as the inventory item preview: translucent black boxes, GrapeSoda 16, black outline + shadow
	gogglesPanel = VBoxContainer.new()
	gogglesPanel.add_theme_constant_override("separation",3)
	gogglesPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gogglesPanel.visible = false
	layer.add_child(gogglesPanel)
	
	var titleBox = makeBox()
	gogglesPanel.add_child(titleBox)
	
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation",4)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titleBox.add_child(head)
	
	var icon = TextureRect.new()
	icon.texture = load("res://items/kinetic/goggles.png")
	icon.custom_minimum_size = Vector2(16,16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(icon)
	
	gogglesTitle = makeLabel("",WHITE)
	head.add_child(gogglesTitle)
	
	gogglesInfoBox = makeBox()
	gogglesPanel.add_child(gogglesInfoBox)
	
	gogglesContent = VBoxContainer.new()
	gogglesContent.add_theme_constant_override("separation",0)
	gogglesContent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gogglesInfoBox.add_child(gogglesContent)
	
	motorPanel = load("res://object_scenes/player/MotorPanel.gd").new()
	add_child(motorPanel)
	
	# Create-style gear (diving set, cardboard box, jetpack) lives on the player
	if parent != null:
		parent.add_child.call_deferred(KineticGear.new())

func makeBox() -> PanelContainer:
	var p = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0,0,0,0.41)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel",sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func makeLabel(text:String,col:Color) -> Label:
	var l = Label.new()
	var ls = LabelSettings.new()
	ls.font = tipFont
	ls.font_size = 16
	ls.font_color = col
	ls.outline_size = 5
	ls.outline_color = Color.BLACK
	ls.shadow_size = 3
	ls.shadow_color = Color.BLACK
	ls.line_spacing = 2
	l.label_settings = ls
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func fmt(n:int) -> String:
	var s :String = str(abs(n))
	var out :String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0,s.length() - 3)
	return ("-" if n < 0 else "") + s + out

# lines: Array of {"t":"text","text":..,"color":..} or {"t":"bar","level":0..3,"color":..,"text":..}
func setTooltip(title:String,lines:Array):
	var sig :String = title + str(lines)
	if sig != gogglesSig:
		gogglesSig = sig
		gogglesTitle.text = title
		for c in gogglesContent.get_children():
			c.queue_free()
		for line in lines:
			if line["t"] == "text":
				gogglesContent.add_child(makeLabel(line["text"],line["color"]))
			else:
				var row = HBoxContainer.new()
				row.add_theme_constant_override("separation",2)
				row.alignment = BoxContainer.ALIGNMENT_BEGIN
				row.mouse_filter = Control.MOUSE_FILTER_IGNORE
				for i in range(3):
					var r = ColorRect.new()
					r.custom_minimum_size = Vector2(8,8)
					r.color = line["color"] if i < int(line["level"]) else Color(0.22,0.2,0.3)
					r.mouse_filter = Control.MOUSE_FILTER_IGNORE
					var holder = CenterContainer.new()
					holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
					holder.add_child(r)
					row.add_child(holder)
				row.add_child(makeLabel(" " + line["text"],line["color"]))
				gogglesContent.add_child(row)
	gogglesPanel.visible = true
	gogglesPanel.reset_size()
	var pos :Vector2 = get_viewport().get_mouse_position() + Vector2(14,14)
	var view :Vector2 = get_viewport().get_visible_rect().size
	pos.x = min(pos.x,view.x - gogglesPanel.size.x - 2)
	pos.y = min(pos.y,view.y - gogglesPanel.size.y - 2)
	gogglesPanel.position = pos

# like the real goggles: only the part that matters for the block you look at
func updateGoggles():
	gogglesPanel.visible = false
	if get_tree().paused or !Stats.hasProperty("goggles"):
		return
	if motorPanel != null and motorPanel.visible:
		return
	if parent.get_local_mouse_position().length() > 160:
		return
	var editBody = parent.getEditingBody()
	if !is_instance_valid(editBody):
		return
	var tile = editBody.posToTile(editBody.get_local_mouse_position())
	if tile == null:
		return
	var info :Dictionary = BlockData.theChunker.getKineticInfo(editBody.DATAC,tile.x,tile.y)
	if !info["kinetic"]:
		return
	
	var id :int = int(info["id"])
	var rpm :float = info["rpm"]
	var supply :int = info["supply"]
	var demand :int = info["demand"]
	var jammed :bool = info["jammed"]
	var lines :Array = []
	
	match id:
		179: # speedometer
			var level :int = 0
			var col :Color = GREY
			var word :String = "Stopped"
			if rpm >= 0.5:
				if rpm < 40:
					level = 1; col = GREEN; word = "Slow"
				elif rpm < 100:
					level = 2; col = BLUE; word = "Moderate"
				else:
					level = 3; col = MAGENTA; word = "Fast"
			lines.append({"t":"text","text":"Rotation Speed","color":GREY})
			lines.append({"t":"bar","level":level,"color":col,"text":word + " (" + str(int(round(rpm))) + " RPM)"})
			setTooltip("Gauge Information:",lines)
		180: # stressometer
			var ratio :float = 0.0
			if supply > 0:
				ratio = float(demand) / float(supply)
			elif demand > 0:
				ratio = 9.99
			var level :int = 1
			var col :Color = GREEN
			var word :String = "Low"
			if jammed or ratio > 1.0:
				level = 3; col = RED; word = "Overstressed"
			elif ratio > 0.5:
				level = 2; col = YELLOW; word = "Moderate"
			lines.append({"t":"text","text":"Network Stress","color":GREY})
			lines.append({"t":"bar","level":level,"color":col,"text":word + " (" + str(min(999,int(round(ratio * 100.0)))) + "%)"})
			lines.append({"t":"text","text":"Remaining Capacity","color":GREY})
			lines.append({"t":"text","text":" " + fmt(max(0,supply - demand)) + "su","color":(GREEN if ratio <= 1.0 else RED)})
			setTooltip("Gauge Information:",lines)
		170, 171, 182, 183, 177, 178: # generators
			var made :int = 0
			if float(info["sourceRpm"]) > 0.0:
				made = int(round(min(rpm,float(info["sourceRpm"])) * int(info["sourceSu"])))
			lines.append({"t":"text","text":"Kinetic Stress Capacity:","color":GREY})
			lines.append({"t":"text","text":" " + fmt(made) + "su at current speed","color":CYAN})
			setTooltip("Generator Stats:",lines)
		172, 173, 184, 185, 186, 188, 189, 191, 192, 193, 194, 196, 197, 198, 199, 200, 202, 203, 204, 205, 206, 207: # machines
			var used :int = int(round(rpm * int(info["impact"])))
			lines.append({"t":"text","text":"Stress Impact:","color":GREY})
			lines.append({"t":"text","text":" " + fmt(used) + "su at current speed","color":ORANGE})
			if jammed:
				lines.append({"t":"text","text":"Jammed!","color":RED})
			elif demand > supply and supply > 0:
				lines.append({"t":"text","text":"Overstressed!","color":RED})
			elif supply == 0:
				lines.append({"t":"text","text":"No power source","color":YELLOW})
			setTooltip("Kinetic Stats:",lines)
		_:
			return # shafts, cogs and gearboxes show nothing, just like the real thing

# right click with a wrench; returns true if it handled the block
func wrenchRotate(editBody,tile,blockType:int) -> bool:
	match blockType:
		101,102,103,104,153,161,172,173,190,199,200,202,203,204,205:
			rotateTile(editBody,tile,blockType) # machines and funnels: down -> left -> up -> right
			return true
		169,170,171,174,175:
			# shafts, cogs and wheels: horizontal <-> vertical
			var axis :int= editBody.DATAC.getInfoData( tile.x, tile.y )
			editBody.DATAC.setInfoData( tile.x, tile.y, (axis + 1) % 2 )
			editBody.editTiles( {Vector2i(tile.x, tile.y):blockType} )
			return true
		182,183:
			# large wheel: flip the axle of all nine pieces
			var info :int = editBody.DATAC.getInfoData( tile.x, tile.y )
			var piece :int = info & 15
			var axis :int = (info >> 4) & 1
			var cx :int = tile.x - (piece % 3 - 1)
			var cy :int = tile.y - (piece / 3 - 1)
			var edits :Dictionary = {}
			for iy in range(-1,2):
				for ix in range(-1,2):
					var id :int = editBody.DATAC.getTileData(cx + ix,cy + iy)
					if id == 182 or id == 183:
						var p :int = (iy + 1) * 3 + (ix + 1)
						editBody.DATAC.setInfoData(cx + ix,cy + iy,p | ((1 - axis) << 4))
						edits[Vector2i(cx + ix,cy + iy)] = id
			editBody.editTiles(edits)
			return true
		177,178:
			motorPanel.open(editBody,Vector2i(tile.x,tile.y))
			return true
		160:
			rotateTile(editBody,tile,160,10)
			return true
		100,152:
			var info :int= editBody.DATAC.getInfoData( tile.x, tile.y )
			editBody.DATAC.setInfoData( tile.x, tile.y, (info + 2) % 8 )
			editBody.editTiles( {Vector2i(tile.x, tile.y):blockType} )
			return true
	return false

# the item in the selected hotbar slot, or null for an empty hand
func heldItem():
	var id :int = PlayerData.getSelectedItemID()
	if id == -1 or !ItemData.data.has(id):
		return null
	return ItemData.data[id]

# arm targets, machine menus and the wrench's arm overlay
func updateKineticUI():
	KineticItems.menuCleanup()
	var held = heldItem()
	if !(held is ItemMechanicalArm):
		KineticItems.armClearPending()
	if !(held is ItemWrench) or get_tree().paused or parent.get_local_mouse_position().length() > 160:
		KineticItems.clearOverlay()
		return
	var editBody = parent.getEditingBody()
	if !is_instance_valid(editBody):
		KineticItems.clearOverlay()
		return
	var tile = editBody.posToTile(editBody.get_local_mouse_position())
	if tile == null:
		KineticItems.clearOverlay()
		return
	var id :int = editBody.DATAC.getTileData(tile.x,tile.y)
	if id == 206 or id == 207:
		KineticItems.showArmOverlay(editBody,Vector2i(tile.x,tile.y))
	else:
		KineticItems.clearOverlay()

func _process(delta):
	visible = !get_tree().paused
	if get_tree().paused:
		gogglesPanel.visible = false
		KineticItems.clearOverlay()
		return
	
	updateGoggles()
	updateKineticUI()
	
	#global_position = get_global_mouse_position()
	rotation = GlobalRef.camera.rotation
	
	if parent.get_local_mouse_position().length() > 48:
		$RightClick.visible = false
		return
	var editBody = parent.getEditingBody()
	if !is_instance_valid(editBody):
		return
	var mousePos = editBody.get_local_mouse_position()
	var tile = editBody.posToTile(mousePos)
	if tile == null:
		return
	var blockType = editBody.DATAC.getTileData(tile.x,tile.y)
	$RightClick.visible = [19,22,23,25,33,34,47,48,55,62,63,97,98,99,100,101,102,103,104,123,126,134,139,147,152,153,160,161,162,167].has(blockType)
	
func onRightClick():
	
	# cancel if out of range
	if parent.get_local_mouse_position().length() > 48:
		return
	
	var editBody = parent.getEditingBody()
	if !is_instance_valid(editBody):
		return
	
	var mousePos = editBody.get_local_mouse_position()
	var tile = editBody.posToTile(mousePos)
	var blockType = editBody.DATAC.getTileData(tile.x,tile.y)
	var rot = editBody.DATAC.getPositionLookup(tile.x,tile.y)
	
	var held = heldItem()
	
	# holding the mechanical arm: choose its targets
	if held is ItemMechanicalArm:
		KineticItems.armSelect(editBody,Vector2i(tile.x,tile.y))
		return
	
	# holding a wrench: rotate / configure instead of the normal interaction
	if held is ItemWrench:
		if wrenchRotate(editBody,tile,blockType):
			return
	
	# rocket ship: needs the Rocket Key, flies to the moon and back
	if Rocket.rightClickBlock(editBody,Vector2i(tile.x,tile.y),blockType):
		return
	
	# machine menus (basin, depot, crushing wheels) and the deployer
	if KineticItems.rightClickBlock(editBody,Vector2i(tile.x,tile.y),blockType):
		return
	
	# right click functionality for each block
	match blockType:
		19: # chair
			
			# return if wall is in the way
			if !parent.wallCheck(parent.get_local_mouse_position()):
				return
			
			if parent.rotated != editBody.DATAC.getPositionLookup(tile.x,tile.y) and editBody is Planet:
				return
			parent.movementState = 1 # enter chair state
			parent.chairSit(tile,editBody)
		22: # closed door
			parent.openDoor(tile,editBody,GlobalRef.playerSide)
			SoundManager.playSound("interacts/door",get_global_mouse_position(),1.2,0.1)
		23: # open door
			parent.closeDoor(tile,editBody)
			SoundManager.playSound("interacts/door",get_global_mouse_position(),1.2,0.1)
		25: # ladder
			
			# return if wall is in the way
			if !parent.wallCheck(parent.get_local_mouse_position()):
				return
			
			if parent.lastOnLadder > 0: # return if player was on a ladder recently
				return
			
			if parent.movementState == 2:
				return
			parent.movementState = 2 # enter ladder state
			if editBody is Planet:
				parent.rotated = editBody.DATAC.getPositionLookup(tile.x,tile.y)
			parent.attachToLadder(tile,editBody)
			SoundManager.playSound("items/ladderClimb",parent.global_position,1.5,0.1)

		33: # chest 
			
			if Network.isMultiplayerGame:
				if Network.multiplayerOpenedChests.has(tile):
					return
			
			if PlayerData.currentSelectedChest == tile:
				PlayerData.closeChest()
				return
			
			PlayerData.closeChest() # force close any existing chest
			
			if PlayerData.loadChest(editBody,tile):
				# chest visual
				var ins = load("res://object_scenes/chest/chest_open.tscn").instantiate()
				ins.position = editBody.tileToPos(tile)
				ins.body = editBody
				ins.pos = tile
				ins.rot = rot
				editBody.entityContainer.add_child(ins)
				SoundManager.playSound("interacts/chest",get_global_mouse_position(),1.0,0.1)
		34: # loot chest
			
			GlobalRef.playerHasInteractedWithChest = true
			editBody.chestDictionary[tile] = LootData.getChestLoot(editBody.planetType)
			editBody.DATAC.setTileData(tile.x,tile.y,33)
			AchievementData.unlockMedal("lootChest")
			if PlayerData.loadChest(editBody,tile):
				# chest visual
				var ins = load("res://object_scenes/chest/chest_open.tscn").instantiate()
				ins.position = editBody.tileToPos(tile)
				ins.body = editBody
				ins.pos = tile
				ins.rot = rot
				editBody.entityContainer.add_child(ins)
				SoundManager.playSound("interacts/chest",get_global_mouse_position(),1.0,0.1)
		47: # trap door
			var dick = parent.setAllTrapdoors(tile,48,editBody)
			editBody.editTiles( dick )
			SoundManager.playSound("interacts/door",get_global_mouse_position(),1.2,0.1)
		48: # trap door
			var dick = parent.setAllTrapdoors(tile,47,editBody)
			editBody.editTiles( dick )
			SoundManager.playSound("interacts/door",get_global_mouse_position(),1.2,0.1)
		55: # bed
			
			if editBody is Ship:
				GlobalRef.sendChat("You can't sleep on a ship!")
				return # fix laying on bed in ship
			else:
				GlobalRef.playerSpawn = editBody.tileToPos(tile)
				GlobalRef.playerSpawnPlanet = editBody
				GlobalRef.sendChat("Set spawnpoint.")
			
			parent.movementState = 3
			parent.position = editBody.tileToPos(tile)
			var info = editBody.DATAC.getInfoData(tile.x,tile.y) % 4
			var d = editBody.DATAC.getPositionLookup(tile.x,tile.y)
			
			var side = (int( info < 2 )*2) - 1 # is 1 or -1 
			
			parent.flipPlayer( side )
			parent.sprite.rotation = (side * -(PI/2)) + ( d * (PI/2) )
			
			if info == 0:
				parent.position += Vector2(8,0).rotated(d * (PI/2))
			elif info == 3:
				parent.position += Vector2(-8,0).rotated(d * (PI/2))
			
			parent.position += Vector2(-side,-3).rotated(d * (PI/2))
		62: # letter block
			var currentLetter = editBody.DATAC.getInfoData(tile.x,tile.y)
			currentLetter = (currentLetter + 1) % 38
			editBody.DATAC.setInfoData(tile.x,tile.y,currentLetter)
			editBody.editTiles( { Vector2i(tile.x,tile.y):62, } )
		63: # ship boss pedastal
			if PlayerData.checkForIngredient(3076,1):
				if CreatureData.spawnBoss(parent.planetOn,parent.position + Vector2(0,-250).rotated(parent.rotated*(PI/2)) ,"bossShip"):
					GlobalRef.sendChat("Summoned big praffin!!")
					PlayerData.consumeItems([3076],[1])
					PlayerData.emit_signal("updateInventory")
			else:
				GlobalRef.sendChat("i need a wax lollipop!!")
		97: # lever
			var info :int= editBody.DATAC.getInfoData( tile.x, tile.y )
			
			var scan :Vector2i = Vector2i( Vector2( 1,0 ).rotated( (info/2) * (PI/2) ))
			
			var tileBelowLever = editBody.DATAC.getTileData( scan.x + tile.x, scan.y + tile.y )
			if tileBelowLever == 91 or tileBelowLever == 93:
				var d = editBody.DATAC.energize( tile.x, tile.y, editBody, BlockData.getLookup() )
				editBody.editTiles( d )
			else:
				var d = editBody.DATAC.energize( scan.x + tile.x, scan.y + tile.y , editBody, BlockData.getLookup() )
				editBody.editTiles( d )
			
			var flip := info % 2
			editBody.DATAC.setInfoData( tile.x, tile.y, ((info/2)*2) + abs(1-flip) )
			editBody.editTiles( {Vector2i(tile.x, tile.y):97} )
			
			SoundManager.playSound("mining/woodBreak",global_position,0.8,0.1)
			
		98: # observer
			var info :int= editBody.DATAC.getInfoData( tile.x, tile.y )
			var target = (info + 2) % 8
			editBody.DATAC.setInfoData( tile.x, tile.y, target )
			editBody.editTiles( {Vector2i(tile.x, tile.y):98} )
		99: # clock trigger
			var info :int= editBody.DATAC.getInfoData( tile.x, tile.y )
			var target = (info + 1) % 8
			editBody.DATAC.setInfoData( tile.x, tile.y, target )
			print(target)
			match target:
				0:
					GlobalRef.sendChat("clock set to 1 second")
				1:
					GlobalRef.sendChat("clock set to 0.5 seconds")
				2:
					GlobalRef.sendChat("clock set to 0.33 seconds")
				3:
					GlobalRef.sendChat("clock set to once per tick")
				4:
					GlobalRef.sendChat("clock set to 2 seconds")
				5:
					GlobalRef.sendChat("clock set to 5 seconds")
				6:
					GlobalRef.sendChat("clock set to 10 seconds")
				7:
					GlobalRef.sendChat("clock set to 30 seconds")
		100: # repeater
			var info :int= editBody.DATAC.getInfoData( tile.x, tile.y )
			var target = (info + 2) % 8
			editBody.DATAC.setInfoData( tile.x, tile.y, target )
			editBody.editTiles( {Vector2i(tile.x, tile.y):100} )
		101: #drill
			rotateTile(editBody,tile,101)
		102: # spitter
			rotateTile(editBody,tile,102)
		103: # extender
			rotateTile(editBody,tile,103)
		104: # placer
			rotateTile(editBody,tile,104)
		105: # conveyor belt
			editBody.editTiles( {Vector2i(tile.x, tile.y):106} )
		106: # conveyor belt
			editBody.editTiles( {Vector2i(tile.x, tile.y):105} )
		123: # flower pot
			var plant = -1
			var itemHeld = PlayerData.getSelectedItemID()
			match itemHeld:
				26:
					plant = 1
				87:
					plant = 2
				76:
					plant = 3
				59:
					plant = 4
				7:
					plant = 5
				110:
					plant = 6
				135:
					plant = 7

			
			if plant > -1:
				editBody.DATAC.setInfoData(tile.x, tile.y, plant)
				editBody.editTiles( {Vector2i(tile.x, tile.y):123} )
		126: # grandfather clock
			var time = GlobalRef.currentTime + 0.2916
			if time > 1.0:
				time -= 1.0
			var hour = int(time * 24.0)
			var minute :int= int(time * 2400.0 * 0.6) - (hour*100 * 0.6)
			var ballsasscockdick = " am."
			if hour > 12:
				hour -= 12
				ballsasscockdick = " pm."
			elif hour == 0:
				hour = 12
			
			if minute < 10:
				GlobalRef.sendChat("The time is " + str(hour) + ":0" + str(minute)+ballsasscockdick)
			else:
				GlobalRef.sendChat("The time is " + str(hour) + ":" + str(minute)+ballsasscockdick)
		
		134: # flowing leaf
			BlockData.spawnItemRaw(tile.x,tile.y,134,editBody)
			editBody.editTiles( {Vector2i(tile.x, tile.y):133} )
		
		139: # shop computer
			
			PlayerData.closeChest()
			
			PlayerData.emit_signal("forceOpenInventory")
			var p = editBody.to_global(editBody.tileToPos(tile))
			SoundManager.playSound("blocks/computer",p,0.8)
			GlobalRef.hotbar.showShop()
			editBody.editTiles( {Vector2i(tile.x, tile.y):140} )
		
		147: # miniboss
			if PlayerData.checkForIngredient(76,5):
				if CreatureData.spawnBoss(parent.planetOn,parent.position + Vector2(0,-64).rotated(parent.rotated*(PI/2)) ,"miniboss"):
					GlobalRef.sendChat("Summoned magician!!")
					PlayerData.consumeItems([76],[5])
					PlayerData.emit_signal("updateInventory")
			else:
				GlobalRef.sendChat("i need 5 glowing orbs...")
		
		152: # info scanner
			var info :int= editBody.DATAC.getInfoData( tile.x, tile.y )
			var target = (info + 2) % 8
			editBody.DATAC.setInfoData( tile.x, tile.y, target )
			editBody.editTiles( {Vector2i(tile.x, tile.y):152} )
		153: # fireball trap
			rotateTile(editBody,tile,153)
		160: # numerical sensor
			rotateTile(editBody,tile,160,10)
		161: # sucker
			rotateTile(editBody,tile,161)
		162: # item frame
			
			var segment = editBody.DATAC.getInfoData(tile.x,tile.y)
			match segment:
				1:
					tile = tile + Vector2(-1,0).rotated( rot * (PI/2) )
				2:
					tile = tile + Vector2(0,-1).rotated( rot * (PI/2) )
				3:
					tile = tile + Vector2(-1,-1).rotated( rot * (PI/2) )
			
			
			var time = editBody.DATAC.getTimeData(tile.x,tile.y)
			
			if time < 0:
				BlockData.spawnItemRaw(tile.x,tile.y,time*-1,editBody)
				editBody.DATAC.setTimeData(tile.x,tile.y, 1) # remove item
				if Network.isMultiplayerGame:
					editBody.editTiles({Vector2i(tile):"itemFramePlace"},true)
				return
			var id = PlayerData.getSelectedItemID()
			if id == -1:
				return # return if not holding item
				
			PlayerData.consumeSelected()
			editBody.DATAC.setTimeData(tile.x,tile.y, id * -1)
			
			
			var ins = load("res://items/blocks/furniture/itemFrame/item_frame_display.tscn").instantiate()
			ins.position = editBody.tileToPos(tile)
			ins.itemId = id
			ins.planet = editBody
			parent.get_parent().add_child(ins)
			
			if Network.isMultiplayerGame:
				editBody.editTiles({Vector2i(tile):"itemFramePlace"},true)


func rotateTile(editBody,tile,block,step:int=4):
	var info :int= editBody.DATAC.getInfoData( tile.x, tile.y )
	var target = (info + 1) % step
	editBody.DATAC.setInfoData( tile.x, tile.y, target )
	editBody.editTiles( {Vector2i(tile.x, tile.y):block} )
