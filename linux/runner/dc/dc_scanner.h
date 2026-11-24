// EventChannel pandive/dc/scan sobre BlueZ (ver dc_scanner.c).
#ifndef PANDIVE_DC_SCANNER_H
#define PANDIVE_DC_SCANNER_H

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

typedef struct _DcScanner DcScanner;

void dc_scanner_register(FlBinaryMessenger *messenger);

G_END_DECLS

#endif
