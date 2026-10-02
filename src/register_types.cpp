#include "register_types.h"

#include "gdexample.h"
#include "chunkdraw.h"
#include "lightmap.h"
#include "lookupBlock.h"
#include "planetData.h"
#include "planetGen.h"

//ADD BLOCKS HERE
#include "block.h"
// We don't necessarily NEED these, it will still work without but it will print ERRORS without them.
#include "blockAir.h"
#include "blockCaveAir.h"
#include "blockStone.h"
#include "blockDirt.h"
#include "blockGrass.h"
#include "blockCore.h"
#include "blockPlasma.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_example_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}

	ClassDB::register_class<GDExample>();
	ClassDB::register_class<CHUNKDRAW>();
	ClassDB::register_class<LIGHTMAP>();
	ClassDB::register_class<LOOKUPBLOCK>();
	ClassDB::register_class<PLANETDATA>();
	ClassDB::register_class<PLANETGEN>();

	//ADD BLOCKS HERE
	ClassDB::register_class<BLOCK>();
	ClassDB::register_class<BLOCKAIR>();
	ClassDB::register_class<BLOCKCAVEAIR>();
	ClassDB::register_class<BLOCKSTONE>();
	ClassDB::register_class<BLOCKDIRT>();
	ClassDB::register_class<BLOCKGRASS>();
	ClassDB::register_class<BLOCKCORE>();
	ClassDB::register_class<BLOCKPLASMA>();

}

void uninitialize_example_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
}

extern "C" {
// Initialization.
GDExtensionBool GDE_EXPORT example_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

	init_obj.register_initializer(initialize_example_module);
	init_obj.register_terminator(uninitialize_example_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

	return init_obj.init();
}
}