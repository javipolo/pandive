// Shared core (Android JNI and Linux) over libdivecomputer: match a BLE name
// with a model and download dives as JSON. Each platform provides the transport
// through pdc_io_t (BleConnection on Android, BlueZ on Linux).
#ifndef PANDIVE_DC_CORE_H
#define PANDIVE_DC_CORE_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    // Reads a packet into buf (up to cap bytes). Returns the number of bytes, 0 if
    // timeout_ms expires without data, <0 on error.
    int (*read_packet)(void *ud, unsigned char *buf, size_t cap, int timeout_ms);
    // Writes size bytes. Returns 0 if ok.
    int (*write)(void *ud, const void *data, size_t size);
    // Progress (current/maximum). Optional.
    void (*progress)(void *ud, int current, int maximum);
    void *ud;
} pdc_io_t;

// Number of supported models (-1 on error).
int pdc_supported_count(void);

// "Vendor Product\n" per model. malloc'd (free).
char *pdc_supported_list(void);

// "Vendor\tProduct" of the model that recognises the BLE name, or "". malloc'd.
char *pdc_match_name(const char *name);

// Opens model vendor/product over io and downloads the dives newer
// than fingerprint_hex ("" = all), at most max_dives (0 = all).
// Returns the JSON {"dives":[...],"count":n[,"error":...]}. malloc'd.
char *pdc_download(const char *vendor, const char *product,
                   const char *fingerprint_hex, int max_dives, pdc_io_t *io);

#ifdef __cplusplus
}
#endif

#endif
