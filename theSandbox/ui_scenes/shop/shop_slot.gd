extends ColorRect

var itemID :int = 2

var amountAvailable :int = 10
var price :int = 1

# tracks the mouse so the card can animate
var mouseInside :bool = false

# price discounted?
var onSale :bool = false

var slotID :int = 0

# forces this slot to appear sold out even if stock would normally exist
var forceStock : bool = false

func _ready():
	# apply the sale first
	if onSale:
		$Sale.show()
		price = max(1,int(price * 0.75))
	
	setInfo()
	PlayerData.connect("updateMoney",updatePriceLabel)
	
	if forceStock:
		amountAvailable = 0
		$soldOutSprite.show()
		$price.hide()
		$itemSprite.modulate = Color.BLACK

func setInfo():
	# load art and price
	$itemSprite.texture = ItemData.getItemTexture(itemID)
	$price.text = "$" + str(price)
	$soldOutSprite.hide()
	updatePriceLabel()

func _process(delta):
	# animate hover effect
	if mouseInside:
		$bg.scale = lerp($bg.scale,Vector2(0.8,0.8),0.2)
	else:
		$bg.scale = lerp($bg.scale,Vector2(1.0,1.0),0.2)

# tooltip function
func _on_mouse_entered():
	var n = ItemData.getItemName(itemID)
	GlobalRef.hotbar.displayItemName(n,ItemData.getItem(itemID))
	mouseInside = true

# clear tooltip
func _on_mouse_exited():
	GlobalRef.hotbar.displayItemName("",null)
	mouseInside = false

func _on_purchase_pressed():
	if Input.is_action_pressed("shift"):
		for i in range(101):
			var response = makePurchase()
			if !response:
				if i == 0:
					return
				SoundManager.playSound("inventory/purchase",GlobalRef.player.global_position,0.3,0.1)
				AchievementData.unlockMedal("makePurchase")
				return
	
	else:
		if makePurchase():
			SoundManager.playSound("inventory/purchase",GlobalRef.player.global_position,0.3,0.1)
			AchievementData.unlockMedal("makePurchase")
	
func makePurchase() -> bool:
	if amountAvailable <= 0:
		return false # return if out of stock
	
	var itemData :Item= ItemData.getItem(itemID)
	var handSlot = PlayerData.getHandSlot()
	if handSlot[0] != -1: # if hold slot isn't empty
		if handSlot[0] != itemID:
			return false # return if the player is holding a different item
		# if player is already holding this item
		if handSlot[1] + 1 > itemData.maxStackSize:
			return false # return if the stack is already full
	
	# player can't afford item
	if PlayerData.money - price < 0:
		updatePriceLabel()
		return false # return if the player is broke
	
	PlayerData.spendMoney(price)
	
	handSlot[0] = itemID
	handSlot[1] = max(1,handSlot[1] + 1)
	
	PlayerData.emit_signal("updateInventory")
	
	# reduce stock
	amountAvailable -= 1
	
	# sold out
	if amountAvailable <= 0:
		$soldOutSprite.show()
		$price.hide()
		$itemSprite.modulate = Color.BLACK
		Saving.shopItems[slotID] = -1
	
	updatePriceLabel()
	
	return true # successful purchase
	
func updatePriceLabel():
	# colors the price red if the player can't afford it
	if PlayerData.money - price < 0:
		$price.modulate = Color.FIREBRICK
	else:
		$price.modulate = Color.WHITE
