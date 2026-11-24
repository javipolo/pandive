// Núcleo común (Android JNI y Linux) sobre libdivecomputer: casar nombre BLE
// con modelo y descargar inmersiones a JSON. El transporte lo pone cada
// plataforma mediante pdc_io_t (BleConnection en Android, BlueZ en Linux).
#ifndef PANDIVE_DC_CORE_H
#define PANDIVE_DC_CORE_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    // Lee un paquete en buf (hasta cap bytes). Devuelve nº de bytes, 0 si
    // vence timeout_ms sin datos, <0 si error.
    int (*read_packet)(void *ud, unsigned char *buf, size_t cap, int timeout_ms);
    // Escribe size bytes. Devuelve 0 si ok.
    int (*write)(void *ud, const void *data, size_t size);
    // Progreso (current/maximum). Opcional.
    void (*progress)(void *ud, int current, int maximum);
    void *ud;
} pdc_io_t;

// Nº de modelos soportados (-1 si error).
int pdc_supported_count(void);

// "Vendor Product\n" por modelo. malloc'd (free).
char *pdc_supported_list(void);

// "Vendor\tProduct" del modelo que reconoce el nombre BLE, o "". malloc'd.
char *pdc_match_name(const char *name);

// Abre el modelo vendor/product sobre io y descarga las inmersiones más
// nuevas que fingerprint_hex ("" = todas), como mucho max_dives (0 = todas).
// Devuelve el JSON {"dives":[...],"count":n[,"error":...]}. malloc'd.
char *pdc_download(const char *vendor, const char *product,
                   const char *fingerprint_hex, int max_dives, pdc_io_t *io);

#ifdef __cplusplus
}
#endif

#endif
