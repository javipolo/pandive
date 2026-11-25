// Linux dive computer plugin: same channels as Android
// (pandive/dc, pandive/dc/scan, pandive/dc/progress) over BlueZ +
// the shared libdivecomputer core (native/pandive_dc_core.c).
#ifndef PANDIVE_DC_PLUGIN_H
#define PANDIVE_DC_PLUGIN_H

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

void dc_plugin_register_with_registrar(FlPluginRegistrar *registrar);

G_END_DECLS

#endif
