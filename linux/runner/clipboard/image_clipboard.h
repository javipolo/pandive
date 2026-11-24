// Copiar una imagen PNG al portapapeles del escritorio (Flutter solo copia
// texto). Canal "pandive/clipboard", método "copyImage" (bytes PNG -> bool).
#ifndef PANDIVE_IMAGE_CLIPBOARD_H_
#define PANDIVE_IMAGE_CLIPBOARD_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

void image_clipboard_register_with_registrar(FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // PANDIVE_IMAGE_CLIPBOARD_H_
