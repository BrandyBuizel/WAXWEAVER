extends Control

# current steam user selected on list
var playerID :int = 0
var username :String = "Player" # default name if Steam API fails to fetch the real one

# periodic avatar refresh timer
var tick :float = 0.0
# random offset to stagger reloads across multiple players
var offset :int = 0

func _ready():
	$Label.text = username
	offset = randi_range(0,40)
	Steam.connect("persona_state_change",updateUsername)
	Steam.connect("avatar_loaded",onAvatarLoaded)
	Steam.getPlayerAvatar(2,playerID)
	
	# wait and check if player is lobby host
	await get_tree().create_timer(0.5).timeout
	
	# show the crown on the host's name
	$Crown.visible = playerID == Network.lobby_host

func _process(delta):
	tick += delta
	if tick > 190.0 + float(offset):
		Steam.getPlayerAvatar(2,playerID) # reload avatar occasionally to account for failures
		tick = 0.0
	
func updateUsername(id,flags):
	if id != playerID:
		return
	username = Steam.getFriendPersonaName(playerID)
	$Label.text = username

func onAvatarLoaded(id,width,data):
	if id != playerID:
		return
	# convert steam profile into an image texture
	var img = Image.create_from_data(width,width,false,Image.FORMAT_RGBA8,data)
	var texture = ImageTexture.create_from_image(img)
	$TextureRect.texture = texture
