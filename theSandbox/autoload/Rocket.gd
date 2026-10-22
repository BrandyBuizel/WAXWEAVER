extends Node
# Rocket ship: right-click a placed rocket (key in inventory) to fly to the moon, and back again.
# The Rocket Key is NOT consumed, so it keeps working for every trip (and for future planets).

const ROCKET_BLOCK :int = 209
const KEY_ID :int = 7161
const ROCKET_ITEM :int = 7160

var launching :bool = false
var layer :CanvasLayer
var fade :ColorRect
var loadingRoot :Control
var loadingLabel :Label
var loadingBar :ColorRect
var loadingBarBack :ColorRect
var tipFont :Font = null

# remembers where on the forest planet the player left from, so the return trip lands back at the same spot
var homeTile :Vector2i = Vector2i(-1,-1)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	tipFont = load("res://zeeg/font/GrapeSoda.ttf")
	layer = CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	
	fade = ColorRect.new()
	fade.color = Color(0,0,0,1)
	fade.modulate.a = 0.0
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	
	loadingRoot = Control.new()
	loadingRoot.set_anchors_preset(Control.PRESET_FULL_RECT)
	loadingRoot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loadingRoot.visible = false
	layer.add_child(loadingRoot)
	
	loadingLabel = Label.new()
	loadingLabel.set_anchors_preset(Control.PRESET_CENTER)
	loadingLabel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	loadingLabel.grow_vertical = Control.GROW_DIRECTION_BOTH
	loadingLabel.position = Vector2(-200,-40)
	loadingLabel.size = Vector2(400,30)
	loadingLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls = LabelSettings.new()
	ls.font = tipFont
	ls.font_size = 24
	ls.font_color = Color.WHITE
	loadingLabel.label_settings = ls
	loadingRoot.add_child(loadingLabel)
	
	loadingBarBack = ColorRect.new()
	loadingBarBack.color = Color(0.2,0.2,0.28,1)
	loadingBarBack.set_anchors_preset(Control.PRESET_CENTER)
	loadingBarBack.position = Vector2(-120,0)
	loadingBarBack.size = Vector2(240,10)
	loadingRoot.add_child(loadingBarBack)
	loadingBar = ColorRect.new()
	loadingBar.color = Color(0.45,0.85,1.0,1)
	loadingBar.position = Vector2.ZERO
	loadingBar.size = Vector2(0,10)
	loadingBarBack.add_child(loadingBar)

func hasKey() -> bool:
	return PlayerData.checkForItemAmount(KEY_ID) > 0

func isOnMoon() -> bool:
	var p = GlobalRef.player
	return is_instance_valid(p) and p.planetOn != null and p.planetOn.planetType == "lunar"

# called from rightClicker before the normal block match. returns true if the click was handled
func rightClickBlock(editBody,tile:Vector2i,blockType:int) -> bool:
	if blockType != ROCKET_BLOCK:
		return false
	if launching:
		return true
	if !(editBody is Planet):
		return true
	if !hasKey():
		GlobalRef.sendError("The rocket is locked. It needs the Rocket Key.")
		return true
	if Network.isMultiplayerGame:
		GlobalRef.sendError("Rocket travel isn't supported in multiplayer yet.")
		return true
	launch(editBody,tile)
	return true

func setBar(v:float):
	loadingBar.size.x = 240.0 * clampf(v,0.0,1.0)

func buildRocketTexture() -> Texture2D:
	# stitch the 10 multitile frames (2 wide x 5 tall) into one 16x40 picture
	var strip :Image = load("res://items/rocket/rocket.png").get_image()
	strip.convert(Image.FORMAT_RGBA8)
	var img := Image.create(16,40,false,Image.FORMAT_RGBA8)
	for i in range(10):
		var cx :int = (i % 2) * 8
		var cy :int = (i / 2) * 8
		img.blit_rect(strip,Rect2i(i*8,0,8,8),Vector2i(cx,cy))
	return ImageTexture.create_from_image(img)

func launch(planet,tile:Vector2i):
	launching = true
	var p :Player = GlobalRef.player
	var toMoon :bool = !isOnMoon()
	
	if toMoon:
		homeTile = tile
	
	# 1. disable controls
	GlobalRef.controlsLocked = true
	GlobalRef.playerCanUseItem = false
	p.velocity = Vector2.ZERO
	p.beingKnockedback = false
	if PlayerData.currentSelectedChest != null:
		PlayerData.closeChest()
	GlobalRef.sendChat("Key accepted. Ignition!",Color(1.0,0.85,0.3))
	
	# 2. the player climbs in, a flying rocket appears where the block is
	var rocketSprite := Sprite2D.new()
	rocketSprite.texture = buildRocketTexture()
	rocketSprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rocketSprite.z_index = 50
	var quad :int = planet.DATAC.getPositionLookup(tile.x,tile.y)
	var up :Vector2 = Vector2(0,-1).rotated(quad * (PI/2))
	rocketSprite.rotation = quad * (PI/2)
	# the clicked tile may be any of the 10 rocket tiles; use the player's spot as the base
	rocketSprite.global_position = p.global_position + up * 12.0
	planet.entityContainer.add_child(rocketSprite)
	p.visible = false
	
	var flame := CPUParticles2D.new()
	flame.amount = 40
	flame.lifetime = 0.5
	flame.local_coords = false
	flame.direction = Vector2(0,1)
	flame.spread = 14.0
	flame.initial_velocity_min = 60.0
	flame.initial_velocity_max = 110.0
	flame.gravity = Vector2.ZERO
	flame.scale_amount_min = 2.0
	flame.scale_amount_max = 4.0
	flame.color = Color(1.0,0.6,0.15,1.0)
	flame.position = Vector2(0,20)
	flame.emitting = false
	rocketSprite.add_child(flame)
	
	# little pre-launch shake, then liftoff
	var shake := create_tween()
	for i in range(14):
		shake.tween_property(rocketSprite,"offset",Vector2(randf_range(-1,1),randf_range(-1,1)),0.05)
	await shake.finished
	rocketSprite.offset = Vector2.ZERO
	flame.emitting = true
	SoundManager.playSound("items/boom",p.global_position,0.6,0.05)
	
	var rise := create_tween()
	rise.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	rise.tween_property(rocketSprite,"global_position",rocketSprite.global_position + up * 900.0,2.6)
	
	# 3. fade to black while it climbs
	await get_tree().create_timer(1.3).timeout
	var f := create_tween()
	f.tween_property(fade,"modulate:a",1.0,1.3)
	await f.finished
	rocketSprite.queue_free()
	
	# 4. loading screen + the actual trip
	loadingRoot.visible = true
	loadingLabel.text = "Traveling to the Moon..." if toMoon else "Returning to the forest planet..."
	setBar(0.0)
	await get_tree().process_frame
	
	var system = GlobalRef.system
	var dest :Planet = system.planets[2] if toMoon else system.mainPlanet
	
	for i in range(1,5):
		setBar(i * 0.06)
		await get_tree().create_timer(0.25).timeout
	
	if toMoon:
		loadingLabel.text = "Building the Moon..."
		await get_tree().process_frame
		ensureMoonGenerated(dest)
	setBar(0.55)
	await get_tree().process_frame
	
	teleportPlayer(p,dest,toMoon)
	
	for i in range(6,11):
		setBar(i * 0.1)
		await get_tree().create_timer(0.3).timeout
	loadingLabel.text = "Touchdown!"
	await get_tree().create_timer(0.4).timeout
	
	# 5. wake up
	loadingRoot.visible = false
	p.visible = true
	p.airTime = 0.0
	p.velocity = Vector2.ZERO
	var fin := create_tween()
	fin.tween_property(fade,"modulate:a",0.0,1.2)
	await fin.finished
	GlobalRef.controlsLocked = false
	GlobalRef.playerCanUseItem = true
	launching = false
	if toMoon:
		GlobalRef.sendChat("Welcome to the Moon. Gravity is low here.",Color(0.6,0.9,1.0))
	else:
		GlobalRef.sendChat("Welcome home.",Color(0.6,1.0,0.6))
	system.saveGameToFile()

func ensureMoonGenerated(moon:Planet):
	var c :int = moon.SIZEINCHUNKS * 4
	# core tile (5) exists only after the moon terrain was generated
	if moon.DATAC.getTileData(c,c) == 5 or moon.DATAC.getTileData(c - 1,c) == 5 or moon.DATAC.getTileData(c,c - 1) == 5:
		return
	moon.noise.seed = randi()
	# call the moon generator directly (generateTerrain would pick skyblock/lattice generators in those world types)
	BlockData.theGenerator.generateMoonPlanet(moon.DATAC,moon.noise)

func teleportPlayer(p:Player,dest:Planet,toMoon:bool):
	var lookup = BlockData.theChunker.returnLookup()
	var spawn :Vector2i
	if !toMoon and homeTile.x >= 0:
		# land beside the rocket we left from
		spawn = homeTile
		var posHome :Vector2 = dest.tileToPos(Vector2(spawn))
		spawn = Vector2i(posHome.round())
	else:
		spawn = dest.DATAC.findSpawnPosition(lookup)
	
	p.global_position = Vector2(spawn) + dest.position
	p.state = 0
	if is_instance_valid(p.planetOn):
		p.detachFromPlanet()
	p.attachToPlanet(dest)
	p.velocity = Vector2.ZERO
	p.airTime = 0.0
	
	if toMoon:
		placeLandedRocket(dest,spawn)

# put a rocket on the moon beside the landing spot so the player can fly home
func placeLandedRocket(moon:Planet,localPos:Vector2i):
	var t = moon.posToTile(Vector2(localPos))
	if t == null:
		return
	var quad :int = moon.DATAC.getPositionLookup(int(t.x),int(t.y))
	var side :Vector2 = Vector2(4,0).rotated(quad * (PI/2))
	var spot = moon.posToTile(Vector2(localPos) + side * 8.0)
	if spot == null:
		return
	# is there already a rocket nearby? then don't add another
	for dx in range(-6,7):
		for dy in range(-6,7):
			if moon.DATAC.getTileData(int(spot.x) + dx,int(spot.y) + dy) == ROCKET_BLOCK:
				return
	var it := ItemMultitile.new()
	it.blockID = ROCKET_BLOCK
	it.size = Vector2i(2,5)
	it.grounded = true
	var sx :int = int(spot.x)
	var sy :int = int(spot.y)
	# clear a pocket of air first so the rocket always fits
	var dir :int = quad
	for xi in range(2):
		for yi in range(6):
			var rot := Vector2(xi,yi - 4).rotated((PI/2) * dir)
			var wx :int = sx + int(round(rot.x))
			var wy :int = sy + int(round(rot.y))
			if yi < 5 and moon.DATAC.getTileData(wx,wy) > 1:
				moon.DATAC.setTileData(wx,wy,1)
	var tiles = it.placeTiles(sx,sy,moon)
	moon.editTiles(tiles,false)
