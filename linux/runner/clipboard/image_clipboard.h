// Copy a PNG image to the desktop clipboard (Flutter only copies
// text). Channel "pandive/clipboard", method "copyImage" (PNG bytes -> bool).
#ifndef PANDIVE_IMAGE_CLIPBOARD_H_
#define PANDIVE_IMAGE_CLIPBOARD_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

void image_clipboard_register_with_registrar(FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // PANDIVE_IMAGE_CLIPBOARD_H_
