extends Node

## MOVEMENT ##
const BASESPEED :float= 98.0
var speedMult :float= 1.0
const BASEJUMP :float= 275.0
var jumpMult :float= 1.0
const BASESWIM :float= 40.0
var swimMult :float = 1.0

const TERMVELOCITY :float = 300.0
const GRAVITY :float = 1000.0

var extraJumps :int = 0

## COMBAT ##
var additiveDefense :int= 0 # Bonus defense
var meleeDamageMult :float = 1.0
var rangedDamageMult :float = 1.0
var bonusHealing :float = 1.0
var knockbackBonus :float = 0.0
var attackSpeedMult :float = 1.0
var criticalStrikeChance :int = 4 # chance out of 100

## OTHER ##
var respawnWait :float = 8.0 # how long until player respawns
var miningMultiplier :float = 1.0 # additional mining speed

var trinkets :Array[int]= [] # array of trinket ids
var specialProperties :Array[String] = [] # array of special tags to give player
var statusImmunities :Array[String]= []

signal updatedStats

###################################
###################################
###################################

###### MOVEMENT #########

func getSpeed():
	return BASESPEED * speedMult

func getSwim():
	return BASESWIM * swimMult

func getJump():
	return BASEJUMP * jumpMult * -1.0

func getGravity():
	return GRAVITY

func getTerminalVelocity():
	return TERMVELOCITY

###### COMBAT #########

func getAdditiveDefense():
	return additiveDefense

func getMeleeDamage(damage):
	var new = float(damage) * meleeDamageMult
	return roundi( new )

func getRangedDamage(damage):
	var new = float(damage) * rangedDamageMult
	return roundi( new )

func getBonusHealing(healing):
	var new = float(healing) * bonusHealing
	return roundi( new )

func getBonusKnockback() -> float:
	return knockbackBonus

func getAttackSpeedMult() -> float:
	return attackSpeedMult

func getCriticalStrikeChance() -> int:
	return criticalStrikeChance

###### TECHNICAL #########

func hasProperty(property:String):
	return specialProperties.has(property)

func resetStats():
	speedMult = 1.0
	jumpMult = 1.0
	swimMult = 1.0
	
	additiveDefense = 0
	meleeDamageMult = 1.0
	rangedDamageMult = 1.0
	bonusHealing = 1.0
	knockbackBonus = 0.0
	attackSpeedMult = 1.0
	criticalStrikeChance = 4
	extraJumps = 0
	
	miningMultiplier = 1.0
	
	trinkets = []
	specialProperties = []
	statusImmunities = []

func updateStats():
	
	resetStats() # clean stats
	
	for slot in range(6): # scan trinket slots
		var data = PlayerData.getSlotItemData(slot + 43)
		if not data is ItemTrinket:
			continue # move to next slot if item is not trinket
		
		trinkets.append( PlayerData.inventory[ slot + 43 ][0] )
		
		# add values
		speedMult += data.addSpeed
		jumpMult += data.addJump
		swimMult += data.addSwim
		additiveDefense += data.addDefense
		meleeDamageMult += data.addMeleeDamage
		rangedDamageMult += data.addRangedDamage
		bonusHealing += data.addHealingMultiplier
		knockbackBonus += data.addKnockback
		attackSpeedMult += data.addAttackSpeed
		criticalStrikeChance += data.addcriticalStrikeChance
		extraJumps += data.extraJumps
		miningMultiplier += data.miningMultiplier
		
		specialProperties += data.specialProperties
		statusImmunities += data.statusImmunities
	
	GlobalRef.playerHC.statusImmunities = statusImmunities
	
	emit_signal("updatedStats")

func emit():
	emit_signal("updatedStats")
