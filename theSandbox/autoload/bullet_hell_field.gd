extends Node2D
# The bullet hell itself. Virtual screen is 400x300 (4:3, same as the game's viewport).
# Playfield on the left, black info box on the right.

signal finished(won:bool)

const W := 400.0
const H := 300.0
const FX := 10.0
const FY := 10.0
const FW := 240.0
const FH := 280.0
const BOSS_NAME := "XHAL'OR"

var font :Font = load("res://zeeg/font/GrapeSoda.ttf")
var bossTex :Texture2D = load("res://object_scenes/entity/enemy_scenes/bosses/lunarBoss/overseer.png")

# ---- state ----
var state :String = "idle" # idle, dialog, battle, boss_explode, gameover
var dialogEnd :bool = false
var t :int = 0

# ---- player ----
var pPos := Vector2(FX + FW / 2.0,FY + FH - 36.0)
var pHealth :int = 5
const P_MAX_HEALTH := 5
var pBombs :int = 3
var pInvuln :int = 0
var bombTimer :int = 0
var shootCd :int = 0
var focused :bool = false
var score :int = 0
var grazeCount :int = 0
var prevX :bool = false
var prevZ :bool = false

# ---- boss ----
var bPos := Vector2(FX + FW / 2.0,FY - 30.0)
var bTarget := Vector2(FX + FW / 2.0,FY + 60.0)
var bHp :float = 1.0
var bMaxHp :float = 1.0
var phase :int = -1
var phaseFrames :int = 0
var phaseLimit :int = 1
var bInvuln :int = 0
var bShout :String = ""
var bShoutTimer :int = 0
var cardName :String = ""
var cardBanner :int = 0
var beamTimer :int = 0
var beamAngle :float = 0.0
var bossFlash :int = 0

var phases :Array = [
	{"name":"","hp":450.0,"time":35,"pos":Vector2(125,60),"shout":"Zhu'kra vel!"},
	{"name":"Nyx-Ora \"Krath'ul Vel\"","hp":600.0,"time":40,"pos":Vector2(125,66),"shout":"Orrem tal ka!"},
	{"name":"Mal-Thra \"Ilu Zhen Ka\"","hp":700.0,"time":45,"pos":Vector2(125,66),"shout":"Vorr'ak mal!"},
	{"name":"Xhal Sign \"Vorr'ak Nyx-Moru\"","hp":900.0,"time":55,"pos":Vector2(125,82),"shout":"NYX-MORU ZHEN!!"},
]

# ---- objects ----
var bullets :Array = [] # {p,v,acc,vmax,r,c,s,gz}
var shots :Array = [] # {p,v,dmg}
var sparks :Array = [] # {p,v,life,max,col,sz}
var rings :Array = [] # {p,r,life,max,col}
var stars :Array = []
var texCache :Dictionary = {}
var flash :float = 0.0
var shake :float = 0.0

# ---- dialog ----
var dialog :Array = []
var dIdx :int = 0
var dChars :float = 0.0

const COLORS := [Color(1.0,0.3,0.3),Color(0.4,0.6,1.0),Color(0.4,1.0,0.5),Color(1.0,0.9,0.3),Color(0.8,0.4,1.0),Color(0.4,1.0,1.0)]

var introLines :Array = [
	["WAXWEAVER","...Wait. Where did the moon go?"],
	["WAXWEAVER","Why is everything black? And why is there a score counter?!"],
	[BOSS_NAME,"Zhu'kra vel nyx! Orrem tal ka-moru?"],
	["WAXWEAVER","Okay, I don't speak alien. But that sounded rude."],
	["WAXWEAVER","Hey. Yeah, YOU. The one holding the keyboard. Stop staring at me."],
	["WAXWEAVER","D-pad to move, Z: fires, X: for bomb... oh and LShift to slow down."],
	[BOSS_NAME,"Vorr'ak zen mal! Ilu-krath ta nyx ora!"],
	["WAXWEAVER","Right. Don't get hit. Easy."],
]
var outroLines :Array = [
	[BOSS_NAME,"Nyx... vel... orrem tal... ka...!"],
	["WAXWEAVER","I think that meant 'ow'."],
	["WAXWEAVER","Okay, how do I get out of this shooting game? ...Oh, a white light. Neat."],
]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 0
	for i in range(60):
		stars.append({"p":Vector2(randf_range(FX,FX + FW),randf_range(FY,FY + FH)),"s":randf_range(0.2,1.2),"z":randf_range(0.6,1.6)})
	for ci in range(COLORS.size()):
		for rad in [2,3,5]:
			texCache[Vector2i(ci,rad)] = makeBulletTex(rad,COLORS[ci])
	set_physics_process(true)

func begin():
	startMusic()
	state = "dialog"
	dialog = introLines
	dIdx = 0
	dChars = 0.0
	dialogEnd = false

# ---------------------------------------------------------------- textures
func makeBulletTex(radius:int,col:Color) -> ImageTexture:
	var size :int = radius * 2 + 3
	var img := Image.create(size,size,false,Image.FORMAT_RGBA8)
	var c := Vector2((size - 1) / 2.0,(size - 1) / 2.0)
	for x in range(size):
		for y in range(size):
			var d :float = Vector2(x,y).distance_to(c)
			if d <= radius * 0.55:
				img.set_pixel(x,y,Color.WHITE)
			elif d <= radius:
				img.set_pixel(x,y,col)
			elif d <= radius + 1.0:
				img.set_pixel(x,y,Color(col.r * 0.4,col.g * 0.4,col.b * 0.4,0.9))
	return ImageTexture.create_from_image(img)

func sfx(file:String,vol:float = 0.5):
	var base = load("res://sound/" + file + ".ogg")
	if base == null:
		return
	# some game sounds (e.g. the final boss beamBlast) are imported as LOOPING.
	# duplicate the stream so we can force it to play once without touching the original.
	var s :AudioStream = base.duplicate()
	if "loop" in s:
		s.loop = false
	var pl := AudioStreamPlayer.new()
	pl.stream = s
	pl.volume_db = linear_to_db(vol)
	pl.bus = "SFX"
	pl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pl)
	pl.finished.connect(pl.queue_free)
	pl.play()

# ---------------------------------------------------------------- music
# Put your own track in ONE of these places (ogg, mp3 or wav):
#   user://music/bullethell.ogg   (works without re-importing; see music/README.txt for the folder)
#   res://music/bullethell.ogg    (inside the project; the editor imports it)
var musicPlayer :AudioStreamPlayer = null

func loadMusic() -> AudioStream:
	for ext in ["ogg","mp3"]:
		var up :String = "user://music/bullethell." + ext
		if FileAccess.file_exists(up):
			if ext == "ogg":
				var o = AudioStreamOggVorbis.load_from_file(up)
				if o != null:
					return o
			else:
				var m := AudioStreamMP3.new()
				m.data = FileAccess.get_file_as_bytes(up)
				return m
	for ext in ["ogg","mp3","wav"]:
		var rp :String = "res://music/bullethell." + ext
		if ResourceLoader.exists(rp):
			var r = load(rp)
			if r is AudioStream:
				return r
	return null

func startMusic():
	var stream :AudioStream = loadMusic()
	if stream == null:
		return
	musicPlayer = AudioStreamPlayer.new()
	musicPlayer.stream = stream
	musicPlayer.bus = "MUSIC"
	musicPlayer.volume_db = linear_to_db(0.8)
	musicPlayer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(musicPlayer)
	musicPlayer.finished.connect(musicPlayer.play) # loop any format
	musicPlayer.play()

func stopMusic(fadeTime:float = 1.0):
	if musicPlayer == null or !is_instance_valid(musicPlayer):
		return
	var mp := musicPlayer
	var tw := create_tween()
	tw.tween_property(mp,"volume_db",-60.0,fadeTime)
	tw.tween_callback(mp.stop)

# ---------------------------------------------------------------- input
func keyDown(k:Key) -> bool:
	return Input.is_key_pressed(k)

func inputVec() -> Vector2:
	var v := Vector2.ZERO
	if keyDown(KEY_LEFT) or Input.is_joy_button_pressed(0,JOY_BUTTON_DPAD_LEFT): v.x -= 1
	if keyDown(KEY_RIGHT) or Input.is_joy_button_pressed(0,JOY_BUTTON_DPAD_RIGHT): v.x += 1
	if keyDown(KEY_UP) or Input.is_joy_button_pressed(0,JOY_BUTTON_DPAD_UP): v.y -= 1
	if keyDown(KEY_DOWN) or Input.is_joy_button_pressed(0,JOY_BUTTON_DPAD_DOWN): v.y += 1
	var ax := Input.get_joy_axis(0,JOY_AXIS_LEFT_X)
	var ay := Input.get_joy_axis(0,JOY_AXIS_LEFT_Y)
	if abs(ax) > 0.3: v.x += ax
	if abs(ay) > 0.3: v.y += ay
	return v.limit_length(1.0)

func zHeld() -> bool:
	return keyDown(KEY_Z) or Input.is_joy_button_pressed(0,JOY_BUTTON_A)

func xHeld() -> bool:
	return keyDown(KEY_X) or Input.is_joy_button_pressed(0,JOY_BUTTON_B) or Input.is_joy_button_pressed(0,JOY_BUTTON_X)

func shiftHeld() -> bool:
	return keyDown(KEY_SHIFT) or Input.is_joy_button_pressed(0,JOY_BUTTON_LEFT_SHOULDER)

# ---------------------------------------------------------------- main loop
func _physics_process(delta):
	t += 1
	updateStars()
	var z :bool = zHeld()
	var zPressed :bool = z and !prevZ
	var xPressed :bool = xHeld() and !prevX
	prevZ = z
	prevX = xHeld()
	if flash > 0.0: flash = max(0.0,flash - 0.03)
	if shake > 0.0: shake = max(0.0,shake - 0.4)
	if bossFlash > 0: bossFlash -= 1
	if bShoutTimer > 0: bShoutTimer -= 1
	if cardBanner > 0: cardBanner -= 1
	
	match state:
		"dialog":
			updateBossIdle()
			updateDialog(zPressed)
		"battle":
			updatePlayer(xPressed)
			updateBoss()
			updateShots()
			updateBullets()
		"boss_explode":
			updateEffects()
			phaseFrames += 1
			if phaseFrames % 3 == 0:
				addSparks(bPos + Vector2(randf_range(-14,14),randf_range(-14,14)),6,Color(1.0,0.8,0.4),2.5)
			if phaseFrames == 60:
				flash = 1.0
				sfx("items/boom",0.7)
			if phaseFrames == 70:
				stopMusic(1.4)
			if phaseFrames > 100:
				state = "idle"
				finished.emit(true)
		"gameover":
			updateEffects()
			phaseFrames += 1
			if phaseFrames == 20:
				stopMusic(1.6)
			if phaseFrames > 150:
				state = "idle"
				finished.emit(false)
	updateEffects()
	queue_redraw()

func updateStars():
	for st in stars:
		var sp :Vector2 = st["p"]
		sp.y += st["s"] * st["z"] * (1.0 if state != "battle" or phase < 3 else 2.4)
		if sp.y > FY + FH:
			sp.y = FY
			sp.x = randf_range(FX,FX + FW)
		st["p"] = sp

func updateBossIdle():
	bPos = bPos.lerp(Vector2(FX + FW / 2.0,FY + 60.0 + sin(t * 0.04) * 6.0),0.04)

# ---------------------------------------------------------------- dialog
func updateDialog(zPressed:bool):
	var line :Array = dialog[dIdx]
	var full :String = line[1]
	dChars += 0.7
	if zPressed:
		if int(dChars) < full.length():
			dChars = full.length()
		else:
			dIdx += 1
			dChars = 0.0
			if dIdx >= dialog.size():
				if dialogEnd:
					state = "boss_explode"
					phaseFrames = 0
					bullets.clear()
				else:
					startBattle()

# ---------------------------------------------------------------- battle flow
func startBattle():
	state = "battle"
	phase = -1
	nextPhase()

func nextPhase():
	phase += 1
	bullets.clear()
	beamTimer = 0
	if phase >= phases.size():
		bossDefeated()
		return
	var ph :Dictionary = phases[phase]
	bMaxHp = ph["hp"]
	bHp = bMaxHp
	phaseFrames = 0
	phaseLimit = int(ph["time"]) * 60
	bTarget = ph["pos"]
	bInvuln = 100
	cardName = ph["name"]
	if cardName != "":
		cardBanner = 200
		flash = 0.6
		sfx("enemy/boss/final/beamBlast",0.35)
	bShout = ph["shout"]
	bShoutTimer = 130

func bossDefeated():
	state = "dialog"
	dialog = outroLines
	dIdx = 0
	dChars = 0.0
	dialogEnd = true
	bullets.clear()
	bTarget = Vector2(FX + FW / 2.0,FY + 70.0)

func damageBoss(amount:float):
	if bInvuln > 0:
		return
	bHp -= amount
	score += 3
	if bHp <= 0.0:
		score += 5000 * (phase + 1)
		addSparks(bPos,24,Color(1.0,0.9,0.6),3.0)
		sfx("items/boom",0.45)
		nextPhase()

# ---------------------------------------------------------------- player
func updatePlayer(xPressed:bool):
	focused = shiftHeld()
	var speed :float = 1.1 if focused else 2.6
	pPos += inputVec() * speed
	pPos.x = clamp(pPos.x,FX + 5.0,FX + FW - 5.0)
	pPos.y = clamp(pPos.y,FY + 6.0,FY + FH - 6.0)
	
	if pInvuln > 0: pInvuln -= 1
	
	# shooting (hold Z)
	if shootCd > 0: shootCd -= 1
	if zHeld() and shootCd <= 0:
		shootCd = 5
		if focused:
			shots.append({"p":pPos + Vector2(-2.5,-6),"v":Vector2(0,-7.0),"dmg":1.1})
			shots.append({"p":pPos + Vector2(2.5,-6),"v":Vector2(0,-7.0),"dmg":1.1})
		else:
			shots.append({"p":pPos + Vector2(0,-6),"v":Vector2(0,-7.0),"dmg":1.0})
			shots.append({"p":pPos + Vector2(-4,-4),"v":Vector2(-0.9,-6.9),"dmg":0.6})
			shots.append({"p":pPos + Vector2(4,-4),"v":Vector2(0.9,-6.9),"dmg":0.6})
	
	# bomb (X)
	if xPressed and pBombs > 0 and bombTimer <= 0:
		pBombs -= 1
		bombTimer = 150
		pInvuln = max(pInvuln,170)
		flash = 0.8
		shake = 4.0
		sfx("items/boom",0.6)
		for i in range(4):
			rings.append({"p":pPos,"r":6.0 + i * 10.0,"life":60 + i * 12,"max":60 + i * 12,"col":COLORS[i % COLORS.size()]})
	if bombTimer > 0:
		bombTimer -= 1
		bullets.clear()
		damageBoss(0.9)
		if bombTimer % 6 == 0:
			rings.append({"p":pPos,"r":4.0,"life":40,"max":40,"col":COLORS[(bombTimer / 6) % COLORS.size()]})
			addSparks(pPos,6,COLORS[(bombTimer / 6) % COLORS.size()],3.0)

func hitPlayer():
	pHealth -= 1
	pInvuln = 150
	shake = 5.0
	flash = 0.5
	sfx("items/lightning",0.35)
	addSparks(pPos,18,Color(1.0,0.4,0.4),3.0)
	# clear the nearby bullets so you get a breather
	var keep :Array = []
	for b in bullets:
		if b["p"].distance_to(pPos) > 70.0:
			keep.append(b)
	bullets = keep
	if pHealth <= 0:
		state = "gameover"
		phaseFrames = 0
		bullets.clear()

func updateShots():
	var keep :Array = []
	for s in shots:
		s["p"] += s["v"]
		if s["p"].y < FY - 8:
			continue
		if bInvuln <= 0 and s["p"].distance_to(bPos) < 14.0:
			damageBoss(s["dmg"])
			addSparks(s["p"],2,Color(1,1,0.7),1.5)
			continue
		keep.append(s)
	shots = keep

# ---------------------------------------------------------------- bullets
func spawnBullet(pos:Vector2,angle:float,speed:float,col:int = 0,size:int = 3,acc:float = 0.0,vmax:float = 0.0):
	if bullets.size() > 1400:
		return
	bullets.append({"p":pos,"v":Vector2.from_angle(angle) * speed,"acc":acc,"vmax":vmax,"r":size * 0.8,"c":col,"s":size,"gz":false})

func ring(count:int,speed:float,offset:float,col:int,size:int,acc:float = 0.0,vmax:float = 0.0):
	for i in range(count):
		spawnBullet(bPos,offset + TAU * i / count,speed,col,size,acc,vmax)

func aimed() -> float:
	return (pPos - bPos).angle()

func updateBullets():
	var keep :Array = []
	for b in bullets:
		if b["acc"] != 0.0:
			var sp :float = b["v"].length() + b["acc"]
			if b["vmax"] > 0.0:
				sp = min(sp,b["vmax"])
			b["v"] = b["v"].normalized() * max(sp,0.05)
		b["p"] += b["v"]
		var p :Vector2 = b["p"]
		if p.x < FX - 18 or p.x > FX + FW + 18 or p.y < FY - 18 or p.y > FY + FH + 18:
			continue
		var d :float = p.distance_to(pPos)
		if pInvuln <= 0 and bombTimer <= 0 and d < b["r"] + 1.4:
			hitPlayer()
			continue
		if !b["gz"] and d < b["r"] + 8.0 and pInvuln <= 0:
			b["gz"] = true
			grazeCount += 1
			score += 10
		keep.append(b)
	bullets = keep

# ---------------------------------------------------------------- boss ai
func updateBoss():
	phaseFrames += 1
	if bInvuln > 0:
		bInvuln -= 1
	bPos = bPos.lerp(bTarget,0.035)
	
	# time out: the spell card just ends
	if phaseFrames > phaseLimit:
		nextPhase()
		return
	if bInvuln > 0:
		return
	
	var pt :int = phaseFrames
	match phase:
		0: attackOne(pt)
		1: attackTwo(pt)
		2: attackThree(pt)
		3: attackFour(pt)

func attackOne(pt:int):
	if pt % 150 == 1:
		bTarget = Vector2(randf_range(FX + 60,FX + FW - 60),randf_range(FY + 45,FY + 85))
	if pt % 50 == 0:
		ring(16,0.9,pt * 0.31,0,3)
	if pt % 100 == 25:
		var a := aimed()
		for i in range(-1,2):
			spawnBullet(bPos,a + i * 0.25,1.3,1,3)

func attackTwo(pt:int):
	bTarget = Vector2(FX + FW / 2.0 + sin(pt * 0.02) * 55.0,FY + 66.0)
	if pt % 4 == 0:
		for arm in range(3):
			spawnBullet(bPos,pt * 0.09 + arm * TAU / 3.0,0.95,4,2)
	if pt % 140 == 70:
		ring(26,0.6,randf() * TAU,3,5)
	if pt % 90 == 0:
		spawnBullet(bPos,aimed(),1.5,0,3)

func attackThree(pt:int):
	bTarget = Vector2(FX + FW / 2.0 + sin(pt * 0.015) * 80.0,FY + 56.0)
	if pt % 6 == 0:
		var x := randf_range(FX,FX + FW)
		bullets.append({"p":Vector2(x,FY - 8),"v":Vector2(randf_range(-0.2,0.2),randf_range(1.0,1.5)),"acc":0.0,"vmax":0.0,"r":2.4,"c":5,"s":3,"gz":false})
	# beam: warning line then a fast stream aimed where the player was
	if pt % 220 == 100:
		beamTimer = 100
		beamAngle = aimed()
	if beamTimer > 0:
		beamTimer -= 1
		if beamTimer < 45 and beamTimer % 2 == 0:
			spawnBullet(bPos,beamAngle,2.8,2,2)
			spawnBullet(bPos,beamAngle + 0.07,2.4,2,2)
			spawnBullet(bPos,beamAngle - 0.07,2.4,2,2)
		elif beamTimer == 99:
			sfx("enemy/boss/final/beamCharge",0.3)

func attackFour(pt:int):
	bTarget = Vector2(FX + FW / 2.0 + sin(pt * 0.012) * 30.0,FY + 82.0)
	if pt % 3 == 0:
		spawnBullet(bPos,pt * 0.11,1.0,4,2)
		spawnBullet(bPos,-pt * 0.09 + PI,1.0,5,2)
	if pt % 110 == 50:
		ring(32,0.5,randf() * TAU,0,3,0.012,1.7)
	if pt % 80 == 0:
		var a := aimed()
		for i in range(-2,3):
			spawnBullet(bPos,a + i * 0.2,1.6,3,3)
	if pt % 240 == 120:
		ring(14,0.7,randf() * TAU,1,5)

# ---------------------------------------------------------------- effects
func addSparks(pos:Vector2,count:int,col:Color,speed:float):
	for i in range(count):
		sparks.append({"p":pos,"v":Vector2.from_angle(randf() * TAU) * randf_range(0.3,speed),"life":randi_range(14,32),"max":32,"col":col})

func updateEffects():
	var keep :Array = []
	for s in sparks:
		s["p"] += s["v"]
		s["v"] *= 0.94
		s["life"] -= 1
		if s["life"] > 0:
			keep.append(s)
	sparks = keep
	var rk :Array = []
	for r in rings:
		r["r"] += 3.2
		r["life"] -= 1
		if r["life"] > 0:
			rk.append(r)
	rings = rk

# ---------------------------------------------------------------- drawing
func _draw():
	var off := Vector2(randf_range(-shake,shake),randf_range(-shake,shake)) if shake > 0.0 else Vector2.ZERO
	draw_set_transform(off,0.0,Vector2.ONE)
	
	# everything is black outside the playfield (this also hides the whole game)
	draw_rect(Rect2(-20,-20,W + 40,H + 40),Color.BLACK)
	
	# playfield background
	var tint :float = 0.0 if phase < 0 else phase * 0.04
	draw_rect(Rect2(FX,FY,FW,FH),Color(0.02 + tint,0.02,0.09 + tint * 0.5))
	for s in stars:
		var a :float = 0.35 + s["z"] * 0.3
		draw_rect(Rect2(s["p"],Vector2(1,1) * (1 if s["z"] < 1.1 else 2)),Color(0.8,0.85,1.0,a))
	
	# beam warning line
	if beamTimer > 45:
		var end :Vector2 = bPos + Vector2.from_angle(beamAngle) * 400.0
		draw_line(bPos,end,Color(0.4,1.0,0.5,0.25 + 0.25 * sin(t * 0.5)),1.0)
	
	# boss
	if state != "idle" and phase < phases.size():
		drawBoss()
	
	# player shots
	for s in shots:
		draw_rect(Rect2(s["p"] - Vector2(0.5,2.5),Vector2(1.5,5)),Color(0.8,1.0,1.0,0.8))
	
	# bullets
	for b in bullets:
		var tex :Texture2D = texCache[Vector2i(b["c"],b["s"])]
		draw_texture(tex,b["p"] - tex.get_size() / 2.0)
	
	# effects
	for r in rings:
		var col :Color = r["col"]
		col.a = float(r["life"]) / float(r["max"]) * 0.8
		draw_arc(r["p"],r["r"],0.0,TAU,40,col,1.5)
	for sp in sparks:
		var c :Color = sp["col"]
		c.a = float(sp["life"]) / float(sp["max"])
		draw_rect(Rect2(sp["p"],Vector2(1.5,1.5)),c)
	
	# player
	if state == "battle" or state == "dialog":
		drawPlayer()
	
	if flash > 0.0:
		draw_rect(Rect2(FX,FY,FW,FH),Color(1,1,1,flash * 0.5))
	
	# black frame around the playfield + the right-hand box
	draw_rect(Rect2(-20,-20,W + 40,FY + 20),Color.BLACK)
	draw_rect(Rect2(-20,FY + FH,W + 40,H),Color.BLACK)
	draw_rect(Rect2(-20,-20,FX + 20,H + 40),Color.BLACK)
	draw_rect(Rect2(FX + FW,-20,W,H + 40),Color.BLACK)
	draw_rect(Rect2(FX - 1,FY - 1,FW + 2,FH + 2),Color(0.35,0.4,0.6),false,1.0)
	drawTopBar()
	drawSidebar()
	if state == "dialog":
		drawDialog()
	if state == "gameover":
		var a :float = min(1.0,phaseFrames / 40.0)
		draw_rect(Rect2(FX,FY,FW,FH),Color(0,0,0,a * 0.6))
		drawText("DEFEATED",Vector2(FX + FW / 2.0,FY + FH / 2.0),32,Color(1,0.4,0.4,a),true)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func drawText(text:String,pos:Vector2,size:int,col:Color,centered:bool = false):
	# the font is a 16px pixel font: only use size 16 (or 32) so every glyph pixel lands on a screen pixel
	var al := HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	var p := pos
	if centered:
		p.x -= 100.0
	draw_string(font,p.round(),text,al,200.0 if centered else -1.0,size,col)

func drawBoss():
	if state == "boss_explode" and phaseFrames > 60:
		return
	var frame :int = (t / 10) % 3
	var sc := 1.5
	var size := Vector2(18,20) * sc
	var col := Color.WHITE
	if bInvuln > 0 and (t / 4) % 2 == 0:
		col = Color(1,1,1,0.5)
	if state == "dialog" and dialogEnd:
		col = Color(1,0.7,0.7)
	draw_texture_rect_region(bossTex,Rect2(bPos - size / 2.0,size),Rect2(frame * 18,0,18,20),col)
	# speech: alien shout
	if bShoutTimer > 0 and state == "battle":
		var a :float = min(1.0,bShoutTimer / 20.0)
		drawText(bShout,bPos + Vector2(0,-20),16,Color(0.9,0.6,1.0,a),true)

func drawPlayer():
	if pInvuln > 0 and (t / 3) % 2 == 0 and state == "battle":
		return
	var c := Color(0.5,0.9,1.0)
	var pts := PackedVector2Array([pPos + Vector2(0,-6),pPos + Vector2(4.5,5),pPos + Vector2(0,2.5),pPos + Vector2(-4.5,5)])
	draw_colored_polygon(pts,c)
	draw_polyline(PackedVector2Array([pts[0],pts[1],pts[2],pts[3],pts[0]]),Color.WHITE,1.0)
	if focused and state == "battle":
		draw_arc(pPos,7.0,0.0,TAU,24,Color(1,1,1,0.5),1.0)
		draw_circle(pPos,1.6,Color(1,0.3,0.3))
		draw_circle(pPos,0.8,Color.WHITE)
	if bombTimer > 0:
		draw_arc(pPos,10.0 + sin(t * 0.4) * 2.0,0.0,TAU,24,Color(0.6,1.0,0.7,0.6),1.5)

func drawTopBar():
	if state != "battle" and !(state == "dialog" and dialogEnd):
		return
	if phase < 0 or phase >= phases.size():
		return
	var x := FX + 4.0
	var y := FY + 3.0
	var w := FW - 40.0
	draw_rect(Rect2(x,y,w,4),Color(0.15,0.05,0.05))
	draw_rect(Rect2(x,y,w * clamp(bHp / bMaxHp,0.0,1.0),4),Color(1.0,0.35,0.35) if bInvuln <= 0 else Color(0.7,0.7,0.7))
	draw_rect(Rect2(x,y,w,4),Color(1,1,1,0.5),false,1.0)
	# remaining phases as stars
	for i in range(phases.size() - phase):
		draw_rect(Rect2(x + i * 7.0,y + 7,4,4),Color(1.0,0.9,0.4))
	# timer
	var left :int = max(0,(phaseLimit - phaseFrames) / 60)
	drawText(str(left),Vector2(FX + FW - 26,FY + 19),16,Color(1,0.8,0.5) if left > 10 else Color(1,0.3,0.3))
	# spell card banner (top right, like the originals)
	if cardName != "" and state == "battle":
		var a :float = min(1.0,cardBanner / 30.0) if cardBanner > 0 else 0.75
		draw_rect(Rect2(FX + 4,FY + 24,FW - 8,18),Color(0.1,0.0,0.15,0.65 * a))
		draw_string(font,Vector2(FX + 8,FY + 37),cardName,HORIZONTAL_ALIGNMENT_LEFT,FW - 16,16,Color(0.9,0.7,1.0,a))

func drawSidebar():
	var x := FX + FW + 12.0
	draw_string(font,Vector2(x,26),"WAXWEAVER",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(0.5,0.9,1.0))
	draw_string(font,Vector2(x,50),"HEALTH",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(1,1,1))
	for i in range(P_MAX_HEALTH):
		var col := Color(1.0,0.3,0.4) if i < pHealth else Color(0.25,0.1,0.12)
		draw_rect(Rect2(x + i * 14.0,56,11,8),col)
		draw_rect(Rect2(x + i * 14.0,56,11,8),Color(1,1,1,0.5),false,1.0)
	draw_string(font,Vector2(x,84),"BOMBS",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(1,1,1))
	for i in range(3):
		var col := Color(0.4,1.0,0.5) if i < pBombs else Color(0.1,0.25,0.12)
		draw_circle(Vector2(x + 5 + i * 14.0,96),4.5,col)
	draw_string(font,Vector2(x,124),"SCORE",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(1,1,1))
	draw_string(font,Vector2(x,142),str(score).pad_zeros(8),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(1.0,0.9,0.5))
	draw_string(font,Vector2(x,164),"GRAZE  " + str(grazeCount),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(0.8,0.9,1.0))
	if phase >= 0 and phase < phases.size():
		draw_string(font,Vector2(x,192),"ENEMY",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(1,1,1))
		draw_string(font,Vector2(x,208),BOSS_NAME,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(0.85,0.55,1.0))
		draw_string(font,Vector2(x,224),"PHASE " + str(phase + 1) + " / " + str(phases.size()),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(0.8,0.8,0.9))
	var hint := Color(0.6,0.65,0.8)
	draw_string(font,Vector2(x,250),"ARROWS move",HORIZONTAL_ALIGNMENT_LEFT,-1,16,hint)
	draw_string(font,Vector2(x,264),"SHIFT slow",HORIZONTAL_ALIGNMENT_LEFT,-1,16,hint)
	draw_string(font,Vector2(x,278),"Z shoot",HORIZONTAL_ALIGNMENT_LEFT,-1,16,hint)
	draw_string(font,Vector2(x,292),"X bomb",HORIZONTAL_ALIGNMENT_LEFT,-1,16,hint)

func drawDialog():
	var line :Array = dialog[dIdx]
	var speaker :String = line[0]
	var full :String = line[1]
	var shown :String = full.substr(0,int(dChars))
	var bx := FX + 6.0
	var bh := 76.0
	var by := FY + FH - bh - 6.0
	var bw := FW - 12.0
	var isBoss :bool = speaker == BOSS_NAME
	var accent := Color(0.85,0.55,1.0) if isBoss else Color(0.5,0.9,1.0)
	var tagW :float = font.get_string_size(speaker,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x + 14.0
	draw_rect(Rect2(bx,by,bw,bh),Color(0.02,0.02,0.08,0.92))
	draw_rect(Rect2(bx,by,bw,bh),accent,false,1.0)
	draw_rect(Rect2(bx + 6,by - 12,tagW,19),Color(0.02,0.02,0.08))
	draw_rect(Rect2(bx + 6,by - 12,tagW,19),accent,false,1.0)
	draw_string(font,Vector2(bx + 13,by + 2),speaker,HORIZONTAL_ALIGNMENT_LEFT,-1,16,accent)
	draw_multiline_string(font,Vector2(bx + 8,by + 25),shown,HORIZONTAL_ALIGNMENT_LEFT,bw - 16,16,-1,Color.WHITE)
	if int(dChars) >= full.length() and (t / 20) % 2 == 0:
		draw_string(font,Vector2(bx + bw - 36,by + bh - 5),"Z >>",HORIZONTAL_ALIGNMENT_LEFT,-1,16,accent)
