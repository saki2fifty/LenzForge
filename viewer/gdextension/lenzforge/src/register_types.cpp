#include "register_types.h"
#include "vid1_reader.h"
#include "lmk1_reader.h"
#include "god1_writer.h"
#include "beard_simulator.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;
using namespace lenzforge;

void initialize_lenzforge_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}

	ClassDB::register_class<VID1Reader>();
	ClassDB::register_class<LMK1Reader>();
	ClassDB::register_class<GOD1Writer>();
	ClassDB::register_class<BeardSimulator>();
}

void uninitialize_lenzforge_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
}

extern "C" {
	GDExtensionBool GDE_EXPORT lenzforge_library_init(
		GDExtensionInterfaceGetProcAddress p_get_proc_address,
		const GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization
	) {
		godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

		init_obj.register_initializer(initialize_lenzforge_module);
		init_obj.register_terminator(uninitialize_lenzforge_module);
		init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

		return init_obj.init();
	}
}
