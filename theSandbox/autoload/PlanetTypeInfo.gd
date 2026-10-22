extends Node


var data = {
	"forest":load("res://world_scenes/planetTypes/ForestType.tres"),
}

var moonType :PlanetType = null

func getData(planetType:String):
	if planetType == "lunar":
		return getMoonType()
	if data.has(planetType):
		return data[planetType]
	return data["forest"]

func rolls(list:Array) -> Array[EnemyRoll]:
	var out :Array[EnemyRoll] = []
	for entry in list:
		var r := EnemyRoll.new()
		r.id = entry[0]
		r.weight = entry[1]
		out.append(r)
	return out

# the moon: aliens on the surface, tougher ones underground. built in code so no extra .tres is needed
func getMoonType() -> PlanetType:
	if moonType != null:
		return moonType
	moonType = PlanetType.new()
	var forest :PlanetType = data["forest"]
	moonType.rareItems = forest.rareItems
	moonType.commonItems = forest.commonItems
	moonType.funItems = forest.funItems
	moonType.fish = forest.fish
	moonType.surfaceDay = rolls([["alien",100]])
	moonType.surfaceNight = rolls([["alien",70],["alienBrute",30]])
	moonType.underground = rolls([["alien",40],["alienBrute",60]])
	moonType.water = rolls([["alien",100]])
	# every other biome context just falls back to the moon creatures too
	moonType.desertDay = moonType.surfaceDay
	moonType.desertNight = moonType.surfaceNight
	moonType.desertUnderground = moonType.underground
	moonType.snowyDay = moonType.surfaceDay
	moonType.snowyNight = moonType.surfaceNight
	moonType.snowyUnderground = moonType.underground
	moonType.moss = moonType.underground
	return moonType
