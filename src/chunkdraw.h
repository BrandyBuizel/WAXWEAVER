#ifndef CHUNKDRAW_H
#define CHUNKDRAW_H

#include <godot_cpp/classes/sprite2d.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/classes/bit_map.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/rect2i.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

#include <godot_cpp/classes/static_body2d.hpp>
#include <godot_cpp/classes/collision_shape2d.hpp>
#include <godot_cpp/classes/collision_polygon2d.hpp>
#include <godot_cpp/classes/rectangle_shape2d.hpp>

#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>

#include "lookupBlock.h"
#include "planetData.h"

namespace godot {

class CHUNKDRAW : public Sprite2D {
	GDCLASS(CHUNKDRAW, Sprite2D)

private:
	double time_passed;
    Array planetData;
	LOOKUPBLOCK *cock;
	BitMap *bitm;

	Ref<Texture2D> texture;
    Ref<Image> texImage;

	Ref<Texture2D> maskHold;
    Ref<Image> maskBorder;

	Ref<Texture2D> watertexture;
    Ref<Image> watertexImage;

protected:
	static void _bind_methods();

public:
	CHUNKDRAW();
	~CHUNKDRAW();

    Array generateTexturesFromData(PLANETDATA *planet,Vector2i pos,Node *body,Ref<Shape2D> shape,bool shipChunk);
	Array drawLiquid(PLANETDATA *planet,Vector2i pos,bool shipChunk);
	Array tickUpdate(PLANETDATA *planet,Vector2i pos,bool onScreen,float daylight);
	Dictionary runBreak(PLANETDATA *planet,Vector2i pos,int x,int y,int blockID);

	int scanBlockOpen(PLANETDATA *planet,int x,int y,int dir);
	int scanBackOpen(PLANETDATA *planet,int x,int y);
	int scanSelfOpen(PLANETDATA *planet,int x,int y,int dir,int ogBlock);
	Vector2i scanForBorder(PLANETDATA *planet,int x,int y);
	Dictionary getBlockDictionary(int id);

	void getBorderImage( const char* file );
	void getBorderMask( const char* file );
	void getWaterImage( const char* file );

	Vector2i getWaterImgPos(PLANETDATA *planet,int x,int y,int blockSide);
	LOOKUPBLOCK* returnLookup();
	int airOrCaveAir(int x,int y, PLANETDATA *planet);
	double getBlockDistance(int x, int y, PLANETDATA *planet);

	void simulateLightOnly(PLANETDATA *planet,Vector2i pos,float daylight);

	void resetLight(PLANETDATA *planet,Vector2i pos);
	Dictionary runOnLoad(PLANETDATA *planet,Vector2i pos);
	Dictionary runOnLoadSingle(PLANETDATA *planet,Vector2i pos);

};

}

#endif