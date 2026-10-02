#include "planetGen.h"
#include <godot_cpp/core/class_db.hpp>


using namespace godot;

void PLANETGEN::_bind_methods() {
    ClassDB::bind_method(D_METHOD("generateForestPlanet","DATAC"), &PLANETGEN::generateForestPlanet);
    ClassDB::bind_method(D_METHOD("generateLunarPlanet","DATAC"), &PLANETGEN::generateLunarPlanet);
    ClassDB::bind_method(D_METHOD("generateSunPlanet","DATAC"), &PLANETGEN::generateSunPlanet);
    ClassDB::bind_method(D_METHOD("generateAridPlanet","DATAC"), &PLANETGEN::generateAridPlanet);
    ClassDB::bind_method(D_METHOD("generateLatticePlanet","DATAC"), &PLANETGEN::generateLatticePlanet);
}

PLANETGEN::PLANETGEN() {
    lookup = memnew(LOOKUPBLOCK);
}

PLANETGEN::~PLANETGEN() {
	// Add your cleanup here.
}


/////////////////// FOREST GENERATION /////////////////

void PLANETGEN::generateForestPlanet(PLANETDATA *planet,FastNoiseLite *noise){
    int planetSize = planet->planetSize;

    int lastSpawnedTree = 16;
    int baseSurface = std::max( planetSize / 4, (planetSize/2) - 128 );
    int skySize = (planetSize - (baseSurface * 2)) / 2;
    Vector2 desertPos = Vector2(0, planetSize/2 );
    Vector2 snowPos = Vector2(planetSize, planetSize/2 );

    bool hasMadeMinibossTemple = false;

    // first pass
    // basic terrain, lakes and oceans
    for(int x = 0; x < planetSize; x++){
        for(int y = 0; y < planetSize; y++){

            int quad = planet->getPositionLookup(x,y);
            int side = Vector2(x,y).rotated(acos(0.0) * quad).x;
            double dis = getBlockDistance(x,y,planet);
            double surface = (noise->get_noise_1d(side*2.0) * 8.0)  +  baseSurface;
            int biome = 0;

            int bodyMaterial = 2;    // stone layer        // these ids are used to determine what material to place depending on the biome
            int surfaceMaterial = 3; // dirt layer
            int toplayerMaterial = 4; // grass layer

            float desertDis = biomeDistanceDetect(desertPos,Vector2(x,y));
            if (desertDis < (planetSize/3) - 2 ){
                int chance = 1;
                if (desertDis > (planetSize/3) - 8 ){
                    chance = 2;
                }
                if (desertDis > (planetSize/3) - 6 ){
                    chance = 4;
                }
                if (desertDis > (planetSize/3) - 4 ){
                    chance = 8;
                }
                
                if (std::rand() % chance == 0){
                    biome = 1; // is desert
                    bodyMaterial = 84;
                    surfaceMaterial = 14;
                    toplayerMaterial = 14;
                }
            }

            float snowDis = biomeDistanceDetect(snowPos,Vector2(x,y));
            if (snowDis < (planetSize/3) - 2 ){
                int chance = 1;
                if (snowDis > (planetSize/3) - 8 ){
                    chance = 2;
                }
                if (snowDis > (planetSize/3) - 6 ){
                    chance = 4;
                }
                if (snowDis > (planetSize/3) - 4 ){
                    chance = 8;
                }
                
                if (std::rand() % chance == 0){
                    biome = 2; // is snow
                    bodyMaterial = 86;
                    surfaceMaterial = 85;
                    toplayerMaterial = 85;
                }

                if( noise->get_noise_2d((x * 4) + 9999, (y * 4) + 9999) > 0.25 ){
                    biome = 2;
                    bodyMaterial = 2;
                }
            }

            if (dis <= surface){
                planet->setTileData(x,y,bodyMaterial);
                planet->setBGData(x,y,bodyMaterial);
            }
            else if (dis <= surface + 4){
                planet->setTileData(x,y,surfaceMaterial);
                planet->setBGData(x,y,surfaceMaterial);
            }
            else if (dis <= surface + 5){
                planet->setTileData(x,y,toplayerMaterial);
                //planet->setBGData(x,y,0);
            }

            double r = (std::abs(dis - (baseSurface * 0.6 ) ) ) / (baseSurface * 0.75);

            int caveSize = 2;
            double n = noise->get_noise_2d(x * caveSize, y * caveSize) + r;

            double marble = noise->get_noise_2d((x+9999) * 1, (y-3123) * 1) + r;

            if (dis <= 24){
                n = n * (dis/24.0);
                if ( n < 0.35 && n > -0.35 ){
                    planet->setBGData(x,y,80);
                    planet->setTileData(x,y,80);
                }

                marble = marble + (1.0 - (dis/24.0));
            }

            if ( n < 0.25 && n > -0.25 ){
                planet->setTileData(x,y, airOrCaveAir(x,y,planet) );
            }

            if( marble > 0.75 ){
                if ( n < 0.38 && n > -0.38 ){
                    if(planet->getTileData(x,y) == 2){
                        planet->setTileData(x,y,114);
                    }

                }
            }



            // lake / ocean stuff
            double lakeSurface = (noise->get_noise_1d((2000 + ( planetSize * quad * 0.75)) + (side*0.75)) * 64.0)  + baseSurface;
            if (dis >= lakeSurface && dis <= surface + 6){
                
                planet->setTileData(x,y, 4 );
                if (biome == 1){planet->setTileData(x,y, 84 );} // sandstone if desert
                if (biome == 2){ planet->setTileData(x,y, 85 ); } // snow if snow biome
                //planet->setBGData(x,y,3);

                int poop = dis - (baseSurface - 15);
                poop = poop / 2;
                if (poop < 3){
                    poop = 3; // for some reason std::min won't work despite std::max working just fine 
                }

                if ( dis <= baseSurface + 3 && dis >= lakeSurface + poop) {
                    
                    planet->setTileData(x,y, 14 );
                    planet->setBGData(x,y,3);
                    if (biome == 2){ planet->setTileData(x,y, 86 ); planet->setBGData(x,y,86); }
                }
                
                if (dis >= lakeSurface + 8){
                    planet->setTileData(x,y, airOrCaveAir(x,y,planet) );
                    planet->setBGData(x,y,0);
                    if ( dis <= baseSurface + 1) {
                        planet->setWaterData(x,y,1.0);
                    }else if(dis <= baseSurface + 2){
                        planet->setWaterData(x,y,0.7);
                    }

                }
            
            }

            if (dis <= 3){
                planet->setTileData(x,y,5);
                planet->setBGData(x,y,5);
            }
        }
    }


    // second pass
    // foliage and ores and chests
    for(int x = 0; x < planetSize; x++){
        for(int y = 0; y < planetSize; y++){

            int quad = planet->getPositionLookup(x,y);
            int side = Vector2(x,y).rotated(acos(0.0) * quad).x;
            int baseSurface = std::max( planetSize / 4, (planetSize/2) - 128 );
            double dis = getBlockDistance(x,y,planet);
            int biome = 0;

            float desertDis = biomeDistanceDetect(desertPos,Vector2(x,y));
            if (desertDis < (planetSize/3) - 2 ){
                biome = 1;
            }

            float snowDis = biomeDistanceDetect(snowPos,Vector2(x,y));
            if (snowDis < (planetSize/3) - 2 ){
                biome = 2;
            }

            if (planet->getTileData(x,y) == 4){ // is grass
                Vector2i up = Vector2i( Vector2(0,-1).rotated(acos(0.0)*quad) );
                if( planet->getTileData(x+up.x,y+up.y) == 0 ){
                    
                    // valid spot for foliage
                    int r = std::rand();
                    if(r % 4 == 0){
                        planet->setTileData(x+up.x,y+up.y,17); // spawn grass
                    }

                    if(r % 32 == 0){
                        planet->setTileData(x+up.x,y+up.y,26); // spawn lily
                    }

                    if(std::rand() % 64 == 0){
                        planet->setTileData(x+up.x,y+up.y,38); // spawn natural potato
                        planet->setInfoData(x+up.x,y+up.y,4);
                    }

                    if (quad % 2 != 0){ // spawns only on left and right side of planet
                        if(std::rand() % 70 == 0){
                            planet->setTileData(x+up.x,y+up.y,54); // spawn house structure
                            planet->setInfoData(x+up.x,y+up.y,0);
                        }

                        if(std::rand() % 5 == 0 && y % 3 == 0){
                            planet->setTileData(x+up.x,y+up.y,7);
                            planet->setTimeData(x+up.x,y+up.y,-16000); // spawn tree sapling
                        }

                    }else{

                        if(std::rand() % 5 == 0 && x % 3 == 0){
                            planet->setTileData(x+up.x,y+up.y,7);
                            planet->setTimeData(x+up.x,y+up.y,-16000); // spawn tree sapling
                        }

                    }


                    if ( quad == 2 ){
                        if(std::rand() % 4 == 0){

                            int roll = (std::rand() % 2) * 2;
                            int upper = up.y * 2;

                            if(std::rand() % 16 == 0){ roll = roll + 4; }

                            planet->setTileData(x+up.x,y+up.y,59); // spawn sunflower
                            planet->setInfoData(x+up.x,y+up.y,1 + roll);
                            planet->setTileData(x+up.x,y+upper,59);
                            planet->setInfoData(x+up.x,y+upper,roll);
                        }
                    }

                }

            }

            if (planet->getTileData(x,y) == 14){ // is sand
                Vector2i up = Vector2i( Vector2(0,-1).rotated(acos(0.0)*quad) );
                if( planet->getTileData(x+up.x,y+up.y) < 2 ){ // if space is free
                    
                    if(std::abs(planet->getWaterData(x+up.x,y+up.y))> 0.1 ){ // is underwater
                        if(std::rand() % 3 == 0){
                            planet->setTileData(x+up.x,y+up.y,90);
                        }
                    }
                    
                    else if(biome == 1){ // is desert

                        if(std::rand() % 2 == 0){ // 50% chance to spawn desert grass
                            planet->setTileData(x+up.x,y+up.y,131);
                            planet->setInfoData(x+up.x,y+up.y,std::rand() % 4); // set appearance
                        }


                        if(std::rand() % 5 == 0){ // 1 in 5 chance to spawn cactus
                            planet->setTileData(x+up.x,y+up.y,87); // spawn cactus
                            planet->setTimeData(x+up.x,y+up.y, ((std::rand() % 40000) + 6000 ) * -1 ); // age cactus randomly
                        }

                    }


                }
            
            }

            if (planet->getTileData(x,y) == 85){ // is snow
                Vector2i up = Vector2i( Vector2(0,-1).rotated(acos(0.0)*quad) );
                if( planet->getTileData(x+up.x,y+up.y) < 2 ){ // if space is free
                    
                    if(std::abs(planet->getWaterData(x+up.x,y+up.y))> 0.1 ){ // is underwater
                        int donothing = 1;
                    }
                    
                    else if(y % 3 == 0){ // is makes sure trees are too squashed together
                        if(std::rand() % 3 == 0){ // 1 in 5 chance to spawn pine tree
                            planet->setTileData(x+up.x,y+up.y,110); // spawn pine tree sapling
                            planet->setTimeData(x+up.x,y+up.y, -10000 ); // age tree so it instantly grows
                        }

                    }

                    if(std::rand() % 100 == 0){ // odds to spawn igloo
                        planet->setTileData(x+up.x,y+up.y,54); // structureblock
                        planet->setInfoData(x+up.x,y+up.y, 4 ); // igloo info id
                    }


                }
            
            }

            if (planet->getTileData(x,y) == 84){ // is sandstone
                Vector2i up = Vector2i( Vector2(0,-1).rotated(acos(0.0)*quad) );

                if(dis < baseSurface - 16){
                    if(std::rand() % 120 == 0){
                        generateOre(planet,x,y,88,84,8); // generate clay 
                    }

                    if(std::rand() % 200 == 0){
                        generateOre(planet,x,y,128,84,8); // generate fossil 
                    }

                    if(std::rand() % 400 == 0){
                        generateOre(planet,x,y,151,84,5); // generate gold
                    }

                    if(planet->getTileData(x+up.x,y+up.y) < 2 && y % 100 == 0){
                        if(std::rand() % 2 == 0 || hasMadeMinibossTemple == false){
                            planet->setTileData(x+up.x,y+up.y,54); // structureblock
                            planet->setInfoData(x+up.x,y+up.y, 11 ); // temple info id
                            hasMadeMinibossTemple = true;
                        }
                    }

                }
                
                if(planet->getTileData(x+up.x,y+up.y) < 2){

                    if(std::rand() % 2 == 0){ // 50% chance to spawn desert grass
                        planet->setTileData(x+up.x,y+up.y,131);
                        planet->setInfoData(x+up.x,y+up.y,std::rand() % 4); // set appearance
                    }

                    if(std::rand() % 3 == 0 && y % 3 == 0){ // generate pink tree
                        planet->setTileData(x+up.x,y+up.y,135);
                        planet->setTimeData(x+up.x,y+up.y,-9999);
                    }
                }
                

                
            }

            if (planet->getTileData(x,y) == 86){ // is ice
                if(std::rand() % 250 == 0){
                    generateOre(planet,x,y,113,86,5); // generate fibers
                }
                
            }
            
            // ores
            if(dis < baseSurface - 16){

                
                if( dis < 64 ) {

                    if(std::rand() % 340 == 0){
                        generateOre(planet,x,y,27,2,7); // generate iron
                    }

                }

                if( dis > 64 ) {
                    if(std::rand() % 300 == 0){
                        generateOre(planet,x,y,18,2,5); // generate copper
                    }
                }

                if(std::rand() % 400 == 0){
                    generateOre(planet,x,y,24,2,3); // generate gold
                }

                if(std::rand() % 500 == 0){
                    generateOre(planet,x,y,28,2,10); // generate gravel
                }

                if(std::rand() % 420 == 0){
                    generateOre(planet,x,y,118,2,12); // generate mossy stone
                }

                if (planet->getTileData(x,y) == 1){ // cave air

                    Vector2i up = Vector2i( Vector2(0,-1).rotated(acos(0.0)*quad) ) + Vector2i(x,y) ;
                    if( planet->getTileData(up.x,up.y) == 2 ){ // found ceiling
                        if(std::rand() % 3 == 0){
                            planet->setTileData(x,y,52); // spawn stalactite
                            planet->setInfoData(x,y, std::rand() % 2 );
                        }else if(std::rand() % 300 == 0){
                            planet->setTileData(x,y,54);
                            planet->setInfoData(x,y, 1 ); // generate cavern house
                        }else if(std::rand() % 260 == 0){
                            planet->setTileData(x,y,54);
                            planet->setInfoData(x,y, 7 ); // generate pillar
                        }
                        
                    }

                    if( planet->getTileData(up.x,up.y) == 86 ){ // found ice ceiling
                        if(std::rand() % 3 == 0){
                            planet->setTileData(x,y,108); // spawn iceicle
                            planet->setInfoData(x,y, std::rand() % 2 );
                        }
                    }


                    Vector2i down = Vector2i( Vector2(0,1).rotated(acos(0.0)*quad) ) + Vector2i(x,y) ;
                    if( planet->getTileData(down.x,down.y) == 2 ){
                        // found suitable stone ground underground

                        if(std::rand() % 3 == 0){
                            planet->setTileData(x,y,119); // spawn rock debris
                            planet->setInfoData(x,y,std::rand() % 12 );
                        }

                        if(std::rand() % 260 == 0){
                            planet->setTileData(x,y,54); // spawn pond
                            planet->setInfoData(x,y, 3 );
                        }

                        if(std::rand() % 250 == 0){
                            planet->setTileData(x,y,34); // spawn loot chest
                        }

                        if(std::rand() % 140 == 0){
                            planet->setTileData(x,y,54); // spawn decor random structure
                            planet->setInfoData(x,y, 6 );
                        }

                    }else if( planet->getTileData(down.x,down.y) == 86 ){ // if 
                        // found suitable ice ground underground
                        if(std::rand() % 100 == 0){
                            planet->setTileData(x,y,34); // spawn loot chest
                        }

                    }else if( planet->getTileData(down.x,down.y) == 114 ){ // if gronud marble
                        if(std::rand() % 30 == 0){
                            planet->setTileData(x,y,54); // spawn marble poop
                            planet->setInfoData(x,y, 10 );
                        }

                        if(std::rand() % 200 == 0){
                            planet->setTileData(x,y,34); // spawn chest
                        }
                    }

                }


            }

            // moss biome
            double r = (std::abs(dis - (baseSurface * 0.6 ) ) ) / (baseSurface * 0.75);

            float caveSize = 0.25;
            double n = noise->get_noise_2d((x+12000) * caveSize, (y+12000) * caveSize) + r;

            int basecaveSize = 2;
            double basen = noise->get_noise_2d(x * basecaveSize, y * basecaveSize) + r;
            if (biome == 2){
                basen = 99.0; // refuse to generate moss in snow biome
            }
            if ( basen < 0.35 && basen > -0.35 ){

                if ( n > 0.3 ){
                    if( planet->getTileData(x,y) == 2 ){
                        planet->setTileData(x,y,74);
                        planet->setTimeData(x,y, (std::rand() % 18000) * -1 ); // makes moss blocks a random amount of old so they can grow things when first loaded

                    }

                    if( planet->getBGData(x,y) == 2 ){
                    planet->setBGData(x,y,74);
                    }
                }
            }


        }
    }

    // end of big loops, spawn structure?

    int randX = (std::rand() % (baseSurface * 2)) + skySize; // finds random position underground
    int randY = (std::rand() % (baseSurface * 2)) + skySize;
    
    //generateBox(planet,randX,randY,5,5,13,13);
    generateLadderPath(planet,randX,randY, planet->getPositionLookup(randX,randY) );

    // generate boss platform
    int sky = ((planetSize/2)-baseSurface);
    int h = (planetSize/2) + ( std::rand() % 300 ) - 150;
    int v = (noise->get_noise_1d(h*2.0) * 8.0) + sky - 2;

    // create rectangle
    for( int x = 0; x < 8; x++ ){
        for( int y = 0; y < 8; y++ ){
            planet->setTileData(x+h-3,y+v-4,0);
        }
    }

    planet->setTileData(h,v,54);
    planet->setInfoData(h,v,2);

}

/////////////////// MOON LUNAR GENERATION /////////////////

void PLANETGEN::generateLunarPlanet(PLANETDATA *planet,FastNoiseLite *noise){
    int planetSize = planet->planetSize;
    for(int x = 0; x < planetSize; x++){
        for(int y = 0; y < planetSize; y++){

            //int quad = planet->getPositionLookup(x,y);
            //int side = Vector2(x,y).rotated(acos(0.0) * quad).x;
            double dis = getBlockDistance(x,y,planet);
            //double surface = (noise->get_noise_1d(side*4.0) * 12.0)  + (planetSize / 4);
            
            if( x == (planetSize/2) - 10 ){
                if(y==368){
                    planet->setTileData(x,y,63);
                    planet->setInfoData(x,y,0);
                }
                if(y==369){
                    planet->setTileData(x,y,63);
                    planet->setInfoData(x,y,2);
                }
                if(y==370){
                    planet->setTileData(x,y,63);
                    planet->setInfoData(x,y,4);
                }
            }
            if( x == (planetSize/2) - 9 ){
                if(y==368){
                    planet->setTileData(x,y,63);
                    planet->setInfoData(x,y,1);
                }
                if(y==369){
                    planet->setTileData(x,y,63);
                    planet->setInfoData(x,y,3);
                }
                if(y==370){
                    planet->setTileData(x,y,63);
                    planet->setInfoData(x,y,5);
                }
            }
            if( x == (planetSize/2) - 8 ){
                if(y==370){
                    planet->setTileData(x,y,147);
                }
            }

            if (dis <= 14 && x == planetSize/2 ){
                
                planet->setTileData(x,y,7);
                planet->setTimeData(x,y,-18000);
            }

            if (dis <= 13){
                planet->setTileData(x,y,4);
                planet->setBGData(x,y,3);
                planet->setTimeData(x,y,-18000);
            }

            if (dis <= 11){
                planet->setTileData(x,y,2);
                planet->setBGData(x,y,2);
            }

            if (dis <= 6){
                planet->setTileData(x,y,14);
                planet->setBGData(x,y,2);
            }

            if (dis <= 5){
                planet->setTileData(x,y,28);
                planet->setBGData(x,y,2);
            }

            if (dis <= 4){
                planet->setTileData(x,y,80);
                planet->setBGData(x,y,80);
            }
            if (dis <= 3){
                planet->setTileData(x,y,5);
                planet->setBGData(x,y,5);
            }
        }
    }
}


////////////////// LATTICE ////////////////////////

void PLANETGEN::generateLatticePlanet(PLANETDATA *planet,FastNoiseLite *noise){
    int planetSize = planet->planetSize;

    int lastSpawnedTree = 16;
    int baseSurface = std::max( planetSize / 4, (planetSize/2) - 128 );
    int skySize = (planetSize - (baseSurface * 2)) / 2;
    Vector2 desertPos = Vector2(0, planetSize/2 );
    Vector2 snowPos = Vector2(planetSize, planetSize/2 );

    bool hasMadeMinibossTemple = false;

    // first pass
    // basic terrain, lakes and oceans
    for(int x = 0; x < planetSize; x++){

        if (x % 2 != 0){ continue; }

        for(int y = 0; y < planetSize; y++){

            if (y % 2 != 0){ continue; }

            int quad = planet->getPositionLookup(x,y);
            int side = Vector2(x,y).rotated(acos(0.0) * quad).x;
            double dis = getBlockDistance(x,y,planet);
            double surface = (noise->get_noise_1d(side*2.0) * 8.0)  +  baseSurface;
            int biome = 0;

            int bodyMaterial = 2;    // stone layer        // these ids are used to determine what material to place depending on the biome
            int surfaceMaterial = 3; // dirt layer
            int toplayerMaterial = 4; // grass layer

            float desertDis = biomeDistanceDetect(desertPos,Vector2(x,y));
            if (desertDis < (planetSize/3) - 2 ){
                int chance = 1;
                if (desertDis > (planetSize/3) - 8 ){
                    chance = 2;
                }
                if (desertDis > (planetSize/3) - 6 ){
                    chance = 4;
                }
                if (desertDis > (planetSize/3) - 4 ){
                    chance = 8;
                }
                
                if (std::rand() % chance == 0){
                    biome = 1; // is desert
                    bodyMaterial = 84;
                    surfaceMaterial = 14;
                    toplayerMaterial = 14;
                }
            }

            float snowDis = biomeDistanceDetect(snowPos,Vector2(x,y));
            if (snowDis < (planetSize/3) - 2 ){
                int chance = 1;
                if (snowDis > (planetSize/3) - 8 ){
                    chance = 2;
                }
                if (snowDis > (planetSize/3) - 6 ){
                    chance = 4;
                }
                if (snowDis > (planetSize/3) - 4 ){
                    chance = 8;
                }
                
                if (std::rand() % chance == 0){
                    biome = 2; // is snow
                    bodyMaterial = 86;
                    surfaceMaterial = 85;
                    toplayerMaterial = 85;
                }

                if( noise->get_noise_2d((x * 4) + 9999, (y * 4) + 9999) > 0.25 ){
                    biome = 2;
                    bodyMaterial = 2;
                }
            }

            if (dis <= surface){
                planet->setTileData(x,y,bodyMaterial);
                planet->setBGData(x,y,bodyMaterial);
            }
            else if (dis <= surface + 4){
                planet->setTileData(x,y,surfaceMaterial);
                planet->setBGData(x,y,surfaceMaterial);
            }
            else if (dis <= surface + 5){
                planet->setTileData(x,y,toplayerMaterial);
                //planet->setBGData(x,y,0);
            }

            double r = (std::abs(dis - (baseSurface * 0.6 ) ) ) / (baseSurface * 0.75);

            int caveSize = 2;
            double n = noise->get_noise_2d(x * caveSize, y * caveSize) + r;

            double marble = noise->get_noise_2d((x+9999) * 1, (y-3123) * 1) + r;

            if (dis <= 24){
                n = n * (dis/24.0);
                if ( n < 0.35 && n > -0.35 ){
                    planet->setBGData(x,y,80);
                    planet->setTileData(x,y,80);
                }

                marble = marble + (1.0 - (dis/24.0));
            }

            if ( n < 0.25 && n > -0.25 ){
                planet->setTileData(x,y, airOrCaveAir(x,y,planet) );
            }

            if( marble > 0.75 ){
                if ( n < 0.38 && n > -0.38 ){
                    if(planet->getTileData(x,y) == 2){
                        planet->setTileData(x,y,114);
                    }

                }
            }



            // lake / ocean stuff
            double lakeSurface = (noise->get_noise_1d((2000 + ( planetSize * quad * 0.75)) + (side*0.75)) * 64.0)  + baseSurface;
            if (dis >= lakeSurface && dis <= surface + 6){
                
                planet->setTileData(x,y, 4 );
                if (biome == 1){planet->setTileData(x,y, 84 );} // sandstone if desert
                if (biome == 2){ planet->setTileData(x,y, 85 ); } // snow if snow biome
                //planet->setBGData(x,y,3);

                int poop = dis - (baseSurface - 15);
                poop = poop / 2;
                if (poop < 3){
                    poop = 3; // for some reason std::min won't work despite std::max working just fine 
                }

                if ( dis <= baseSurface + 3 && dis >= lakeSurface + poop) {
                    
                    planet->setTileData(x,y, 14 );
                    planet->setBGData(x,y,3);
                    if (biome == 2){ planet->setTileData(x,y, 86 ); planet->setBGData(x,y,86); }
                }
                
                if (dis >= lakeSurface + 8){
                    planet->setTileData(x,y, airOrCaveAir(x,y,planet) );
                    planet->setBGData(x,y,0);
                    if ( dis <= baseSurface + 1) {
                        planet->setWaterData(x,y,1.0);
                    }else if(dis <= baseSurface + 2){
                        planet->setWaterData(x,y,0.7);
                    }

                }
            
            }

            if (dis <= 3){
                planet->setTileData(x,y,5);
                planet->setBGData(x,y,5);
            }
        }
    }


    // second pass
    // foliage and ores and chests
    for(int x = 0; x < planetSize; x++){

        if (x % 2 != 0){ continue; }

        for(int y = 0; y < planetSize; y++){

            if (y % 2 != 0){ continue; }

            int quad = planet->getPositionLookup(x,y);
            int side = Vector2(x,y).rotated(acos(0.0) * quad).x;
            int baseSurface = std::max( planetSize / 4, (planetSize/2) - 128 );
            double dis = getBlockDistance(x,y,planet);
            int biome = 0;

            float desertDis = biomeDistanceDetect(desertPos,Vector2(x,y));
            if (desertDis < (planetSize/3) - 2 ){
                biome = 1;
            }

            float snowDis = biomeDistanceDetect(snowPos,Vector2(x,y));
            if (snowDis < (planetSize/3) - 2 ){
                biome = 2;
            }

            if (planet->getTileData(x,y) == 4){ // is grass
                Vector2i up = Vector2i( Vector2(0,-1).rotated(acos(0.0)*quad) );
                if( planet->getTileData(x+up.x,y+up.y) == 0 ){
                    
                    // valid spot for foliage
                    int r = std::rand();
                    if(r % 4 == 0){
                        planet->setTileData(x+up.x,y+up.y,17); // spawn grass
                    }

                    if(r % 32 == 0){
                        planet->setTileData(x+up.x,y+up.y,26); // spawn lily
                    }

                    if(std::rand() % 64 == 0){
                        planet->setTileData(x+up.x,y+up.y,38); // spawn natural potato
                        planet->setInfoData(x+up.x,y+up.y,4);
                    }

                    if (quad % 2 != 0){ // spawns only on left and right side of planet
                        if(std::rand() % 70 == 0){
                            planet->setTileData(x+up.x,y+up.y,54); // spawn house structure
                            planet->setInfoData(x+up.x,y+up.y,0);
                        }

                        if(std::rand() % 5 == 0 && y % 3 == 0){
                            planet->setTileData(x+up.x,y+up.y,7);
                            planet->setTimeData(x+up.x,y+up.y,-16000); // spawn tree sapling
                        }

                    }else{

                        if(std::rand() % 5 == 0 && x % 3 == 0){
                            planet->setTileData(x+up.x,y+up.y,7);
                            planet->setTimeData(x+up.x,y+up.y,-16000); // spawn tree sapling
                        }

                    }


                    if ( quad == 2 ){
                        if(std::rand() % 4 == 0){

                            int roll = (std::rand() % 2) * 2;
                            int upper = up.y * 2;

                            if(std::rand() % 16 == 0){ roll = roll + 4; }

                            planet->setTileData(x+up.x,y+up.y,59); // spawn sunflower
                            planet->setInfoData(x+up.x,y+up.y,1 + roll);
                            planet->setTileData(x+up.x,y+upper,59);
                            planet->setInfoData(x+up.x,y+upper,roll);
                        }
                    }

                }

            }

            if (planet->getTileData(x,y) == 14){ // is sand
                Vector2i up = Vector2i( Vector2(0,-1).rotated(acos(0.0)*quad) );
                if( planet->getTileData(x+up.x,y+up.y) < 2 ){ // if space is free
                    
                    if(std::abs(planet->getWaterData(x+up.x,y+up.y))> 0.1 ){ // is underwater
                        if(std::rand() % 3 == 0){
                            planet->setTileData(x+up.x,y+up.y,90);
                        }
                    }
                    
                    else if(biome == 1){ // is desert

                        if(std::rand() % 2 == 0){ // 50% chance to spawn desert grass
                            planet->setTileData(x+up.x,y+up.y,131);
                            planet->setInfoData(x+up.x,y+up.y,std::rand() % 4); // set appearance
                        }


                        if(std::rand() % 5 == 0){ // 1 in 5 chance to spawn cactus
                            planet->setTileData(x+up.x,y+up.y,87); // spawn cactus
                            planet->setTimeData(x+up.x,y+up.y, ((std::rand() % 40000) + 6000 ) * -1 ); // age cactus randomly
                        }

                    }


                }
            
            }

            if (planet->getTileData(x,y) == 85){ // is snow
                Vector2i up = Vector2i( Vector2(0,-1).rotated(acos(0.0)*quad) );
                if( planet->getTileData(x+up.x,y+up.y) < 2 ){ // if space is free
                    
                    if(std::abs(planet->getWaterData(x+up.x,y+up.y))> 0.1 ){ // is underwater
                        int donothing = 1;
                    }
                    
                    else if(y % 3 == 0){ // is makes sure trees are too squashed together
                        if(std::rand() % 3 == 0){ // 1 in 5 chance to spawn pine tree
                            planet->setTileData(x+up.x,y+up.y,110); // spawn pine tree sapling
                            planet->setTimeData(x+up.x,y+up.y, -10000 ); // age tree so it instantly grows
                        }

                    }

                    if(std::rand() % 100 == 0){ // odds to spawn igloo
                        planet->setTileData(x+up.x,y+up.y,54); // structureblock
                        planet->setInfoData(x+up.x,y+up.y, 4 ); // igloo info id
                    }


                }
            
            }

            if (planet->getTileData(x,y) == 84){ // is sandstone
                Vector2i up = Vector2i( Vector2(0,-1).rotated(acos(0.0)*quad) );

                if(dis < baseSurface - 16){
                    if(std::rand() % 120 == 0){
                        generateOre(planet,x,y,88,84,8); // generate clay 
                    }

                    if(std::rand() % 200 == 0){
                        generateOre(planet,x,y,128,84,8); // generate fossil 
                    }

                    if(std::rand() % 400 == 0){
                        generateOre(planet,x,y,151,84,5); // generate gold
                    }

                    if(planet->getTileData(x+up.x,y+up.y) < 2 && y % 100 == 0){
                        if(std::rand() % 2 == 0 || hasMadeMinibossTemple == false){
                            planet->setTileData(x+up.x,y+up.y,54); // structureblock
                            planet->setInfoData(x+up.x,y+up.y, 11 ); // temple info id
                            hasMadeMinibossTemple = true;
                        }
                    }

                }
                
                if(planet->getTileData(x+up.x,y+up.y) < 2){

                    if(std::rand() % 2 == 0){ // 50% chance to spawn desert grass
                        planet->setTileData(x+up.x,y+up.y,131);
                        planet->setInfoData(x+up.x,y+up.y,std::rand() % 4); // set appearance
                    }

                    if(std::rand() % 3 == 0 && y % 3 == 0){ // generate pink tree
                        planet->setTileData(x+up.x,y+up.y,135);
                        planet->setTimeData(x+up.x,y+up.y,-9999);
                    }
                }
                

                
            }

            if (planet->getTileData(x,y) == 86){ // is ice
                if(std::rand() % 250 == 0){
                    generateOre(planet,x,y,113,86,5); // generate fibers
                }
                
            }
            
            // ores
            if(dis < baseSurface - 16){

                
                if( dis < 64 ) {

                    if(std::rand() % 340 == 0){
                        generateOre(planet,x,y,27,2,7); // generate iron
                    }

                }

                if( dis > 64 ) {
                    if(std::rand() % 300 == 0){
                        generateOre(planet,x,y,18,2,5); // generate copper
                    }
                }

                if(std::rand() % 400 == 0){
                    generateOre(planet,x,y,24,2,3); // generate gold
                }

                if(std::rand() % 500 == 0){
                    generateOre(planet,x,y,28,2,10); // generate gravel
                }

                if(std::rand() % 420 == 0){
                    generateOre(planet,x,y,118,2,12); // generate mossy stone
                }

                if (planet->getTileData(x,y) == 1){ // cave air

                    Vector2i up = Vector2i( Vector2(0,-1).rotated(acos(0.0)*quad) ) + Vector2i(x,y) ;
                    if( planet->getTileData(up.x,up.y) == 2 ){ // found ceiling
                        if(std::rand() % 3 == 0){
                            planet->setTileData(x,y,52); // spawn stalactite
                            planet->setInfoData(x,y, std::rand() % 2 );
                        }else if(std::rand() % 300 == 0){
                            planet->setTileData(x,y,54);
                            planet->setInfoData(x,y, 1 ); // generate cavern house
                        }else if(std::rand() % 260 == 0){
                            planet->setTileData(x,y,54);
                            planet->setInfoData(x,y, 7 ); // generate pillar
                        }
                        
                    }

                    if( planet->getTileData(up.x,up.y) == 86 ){ // found ice ceiling
                        if(std::rand() % 3 == 0){
                            planet->setTileData(x,y,108); // spawn iceicle
                            planet->setInfoData(x,y, std::rand() % 2 );
                        }
                    }


                    Vector2i down = Vector2i( Vector2(0,1).rotated(acos(0.0)*quad) ) + Vector2i(x,y) ;
                    if( planet->getTileData(down.x,down.y) == 2 ){
                        // found suitable stone ground underground

                        if(std::rand() % 3 == 0){
                            planet->setTileData(x,y,119); // spawn rock debris
                            planet->setInfoData(x,y,std::rand() % 12 );
                        }

                        if(std::rand() % 260 == 0){
                            planet->setTileData(x,y,54); // spawn pond
                            planet->setInfoData(x,y, 3 );
                        }

                        if(std::rand() % 250 == 0){
                            planet->setTileData(x,y,34); // spawn loot chest
                        }

                        if(std::rand() % 140 == 0){
                            planet->setTileData(x,y,54); // spawn decor random structure
                            planet->setInfoData(x,y, 6 );
                        }

                    }else if( planet->getTileData(down.x,down.y) == 86 ){ // if 
                        // found suitable ice ground underground
                        if(std::rand() % 100 == 0){
                            planet->setTileData(x,y,34); // spawn loot chest
                        }

                    }else if( planet->getTileData(down.x,down.y) == 114 ){ // if gronud marble
                        if(std::rand() % 30 == 0){
                            planet->setTileData(x,y,54); // spawn marble poop
                            planet->setInfoData(x,y, 10 );
                        }

                        if(std::rand() % 200 == 0){
                            planet->setTileData(x,y,34); // spawn chest
                        }
                    }

                }


            }

            // moss biome
            double r = (std::abs(dis - (baseSurface * 0.6 ) ) ) / (baseSurface * 0.75);

            float caveSize = 0.25;
            double n = noise->get_noise_2d((x+12000) * caveSize, (y+12000) * caveSize) + r;

            int basecaveSize = 2;
            double basen = noise->get_noise_2d(x * basecaveSize, y * basecaveSize) + r;
            if (biome == 2){
                basen = 99.0; // refuse to generate moss in snow biome
            }
            if ( basen < 0.35 && basen > -0.35 ){

                if ( n > 0.3 ){
                    if( planet->getTileData(x,y) == 2 ){
                        planet->setTileData(x,y,74);
                        planet->setTimeData(x,y, (std::rand() % 18000) * -1 ); // makes moss blocks a random amount of old so they can grow things when first loaded

                    }

                    if( planet->getBGData(x,y) == 2 ){
                    planet->setBGData(x,y,74);
                    }
                }
            }


        }
    }

    // end of big loops, spawn structure?

    int randX = (std::rand() % (baseSurface * 2)) + skySize; // finds random position underground
    int randY = (std::rand() % (baseSurface * 2)) + skySize;
    
    //generateBox(planet,randX,randY,5,5,13,13);
    generateLadderPath(planet,randX,randY, planet->getPositionLookup(randX,randY) );

    // generate boss platform
    int sky = ((planetSize/2)-baseSurface);
    int h = (planetSize/2) + ( std::rand() % 300 ) - 150;
    int v = (noise->get_noise_1d(h*2.0) * 8.0) + sky - 2;

    // create rectangle
    for( int x = 0; x < 8; x++ ){
        for( int y = 0; y < 8; y++ ){
            planet->setTileData(x+h-3,y+v-4,0);
        }
    }

    planet->setTileData(h,v,54);
    planet->setInfoData(h,v,2);

}


/////////////////// SUN GENERATION /////////////////

void PLANETGEN::generateSunPlanet(PLANETDATA *planet,FastNoiseLite *noise){
    int planetSize = planet->planetSize;
    for(int x = 0; x < planetSize; x++){
        for(int y = 0; y < planetSize; y++){
            
            double dis = getBlockDistance(x,y,planet);
            double surface = (planetSize / 4);

            if (dis <= surface){
                planet->setTileData(x,y,6);
                planet->setBGData(x,y,0);
            }
        }
    }
}

/////////////////// ARID GENERATION /////////////////

void PLANETGEN::generateAridPlanet(PLANETDATA *planet,FastNoiseLite *noise){
    int planetSize = planet->planetSize;

    int baseSurface = std::max( planetSize / 4, (planetSize/2) - 128 );

    for(int x = 0; x < planetSize; x++){
        for(int y = 0; y < planetSize; y++){

            int quad = planet->getPositionLookup(x,y);
            int side = Vector2(x,y).rotated(acos(0.0) * quad).x;
            double dis = getBlockDistance(x,y,planet);
            double surface = (noise->get_noise_1d(side*2.0) * 8.0)  +  baseSurface;

            if (dis <= surface){
                planet->setTileData(x,y,2); // remember to add sandstone in here eventually
                planet->setBGData(x,y,2);
            }else if (dis <= surface + 4){ 
                planet->setTileData(x,y,14);
                planet->setBGData(x,y,14);
            }
            if (dis <= 3){ // core
                planet->setTileData(x,y,5);
                planet->setBGData(x,y,5);
            }
        }
    }
}

//////////////////////// MATH /////////////////////////////////

double PLANETGEN::getBlockDistance(int x, int y, PLANETDATA *planet){
    int planetSize = planet->planetSize;
    int quad = planet->getPositionLookup(x,y);
    Vector2 newPos = Vector2(x - (planetSize / 2) + 0.5, y - (planetSize / 2) + 0.5 ) ;
    newPos = newPos.rotated(acos(0.0) * -quad);


    return -newPos.y;
}

int PLANETGEN::airOrCaveAir(int x,int y, PLANETDATA *planet){
    int planetSize = planet->planetSize;
    int surface = std::max( planetSize / 4, (planetSize/2) - 128 );
    int b = getBlockDistance(x, y, planet) <= surface - 2;
    return b;
}

void PLANETGEN::generateOre(PLANETDATA *planet,int x,int y,int oreID,int replaceID,int cycles){
    if( planet->getTileData(x,y) != replaceID ){
        return;
    }

    // set original ore
    planet->setTileData(x,y,oreID);

    Vector2i offset = Vector2i(0,0);

    for(int c = 0; c < cycles; c++){
        // run through cycles

        offset = offset + Vector2i( Vector2(1,1).rotated( acos(0.0) * (std::rand() % 4) ) );


        for(int d = 0; d < 4; d++){

            Vector2i coolerOffset = Vector2i( Vector2(1,0).rotated( acos(0.0)*d ) );
            Vector2i pos = offset + Vector2i(x,y) + coolerOffset;

            if( planet->getTileData(pos.x,pos.y) == replaceID ){
                planet->setTileData(pos.x,pos.y,oreID);
                planet->setTimeData(pos.x,pos.y,-10000);
            }


        }

        
    
    }

}

void PLANETGEN::generateBox(PLANETDATA *planet,int x, int y, int wallID, int bgID){


    

    for (int xx = 0; xx < 5; xx++){
        for (int yy = 0; yy < 5; yy++){

            Vector2i p = Vector2i( x + xx, y + yy );

            planet->setBGData(p.x,p.y,bgID);

            if (xx == 0 || yy == 0 || xx == 4 || yy == 4){
                planet->setTileData(p.x,p.y,wallID);
            } else {
                planet->setTileData(p.x,p.y,airOrCaveAir(p.x,p.y,planet));
            }

        }

    }

}

void PLANETGEN::generateLadderPath(PLANETDATA *planet,int x, int y, int dir){
    int length = (std::rand() % 128) + 128;

    for (int i = 0; i < length; i++){
        Vector2i pos = Vector2i( Vector2(0,i).rotated( acos(0.0) * dir ) );
        Vector2i L = Vector2i( Vector2(-1,0).rotated( acos(0.0) * dir ) );
        Vector2i R = Vector2i( Vector2(1,0).rotated( acos(0.0) * dir ) );

        if (planet->getTileData( x + pos.x, y + pos.y ) == 5 ){
            continue; // continue if trying to delete core
        }

        planet->setTileData( x + pos.x + L.x, y + pos.y + L.y, 1 );
        planet->setTileData( x + pos.x + R.x, y + pos.y + R.y, 1 );

        if ( dir % 2 == planet->getPositionLookup( x + pos.x, y + pos.y ) % 2 ){

            planet->setTileData( x + pos.x, y + pos.y, 25 );
        }else{
            planet->setTileData( x + pos.x, y + pos.y, 1 );
        }


    }

}

float PLANETGEN::biomeDistanceDetect(Vector2 source, Vector2 pos){
    return source.distance_to(pos);
}