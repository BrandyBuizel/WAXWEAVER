#ifndef PLANETGEN_H
#define PLANETGEN_H

#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/classes/sprite2d.hpp>
#include <godot_cpp/classes/fast_noise_lite.hpp>

#include <algorithm>

#include "planetData.h"
#include "lookupBlock.h"

namespace godot {

class PLANETGEN : public Sprite2D {
	GDCLASS(PLANETGEN, Sprite2D)

private:
    LOOKUPBLOCK *lookup;

protected:
	static void _bind_methods();

public:
	PLANETGEN();
	~PLANETGEN();

    void generateForestPlanet(PLANETDATA *planet, FastNoiseLite *noise);
    void generateLunarPlanet(PLANETDATA *planet, FastNoiseLite *noise);
    void generateSunPlanet(PLANETDATA *planet, FastNoiseLite *noise);
    void generateAridPlanet(PLANETDATA *planet, FastNoiseLite *noise);
    void generateLatticePlanet(PLANETDATA *planet, FastNoiseLite *noise);
    
    
    double getBlockDistance(int x, int y, PLANETDATA *planet);
    int airOrCaveAir(int x,int y, PLANETDATA *planet);
    void generateOre(PLANETDATA *planet,int x,int y,int oreID,int replaceID,int cycles);
    void generateBox(PLANETDATA *planet,int x, int y, int wallID, int bgID);
    void generateLadderPath(PLANETDATA *planet,int x, int y, int dir);

    float biomeDistanceDetect(Vector2 source, Vector2 pos);
	
};

}

#endif