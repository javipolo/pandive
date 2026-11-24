// Plugin Linux del ordenador de buceo: mismos canales que Android
// (pandive/dc, pandive/dc/scan, pandive/dc/progress) sobre BlueZ +
// el núcleo común de libdivecomputer (native/pandive_dc_core.c).
#ifndef PANDIVE_DC_PLUGIN_H
#define PANDIVE_DC_PLUGIN_H

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

void dc_plugin_register_with_registrar(FlPluginRegistrar *registrar);

G_END_DECLS

#endif
