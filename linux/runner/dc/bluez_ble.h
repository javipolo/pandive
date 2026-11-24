// BLE sobre BlueZ (D-Bus, GIO): adaptador, escaneo y una conexión GATT
// expuesta como flujo de paquetes síncrono para libdivecomputer. Equivale a
// BleScanner/BleConnection de Android.
#ifndef PANDIVE_BLUEZ_BLE_H
#define PANDIVE_BLUEZ_BLE_H

#include <gio/gio.h>

G_BEGIN_DECLS

// Ruta del primer adaptador ("/org/bluez/hci0") o NULL. powered opcional.
gchar *bluez_adapter_path(GDBusConnection *bus, gboolean *powered);

// Enciende el adaptador (puede fallar por rfkill/polkit; se ignora).
void bluez_power_on(GDBusConnection *bus);

// ¿El nombre parece de un ordenador de buceo? (para destacarlo en el escaneo)
gboolean bluez_likely_dive_computer(const gchar *name);

typedef struct _BleConn BleConn;

// Conecta (bloqueante) al dispositivo con esa MAC. Llamar desde un hilo de
// trabajo: usa su propio GMainContext. NULL + *error si falla.
BleConn *ble_conn_open(const gchar *address, int timeout_ms, gchar **error);

// Siguiente paquete recibido: nº de bytes, 0 si vence el timeout, <0 si error.
int ble_conn_read(BleConn *c, unsigned char *buf, gsize cap, int timeout_ms);

// Escribe un paquete. 0 si ok.
int ble_conn_write(BleConn *c, const void *data, gsize size);

void ble_conn_close(BleConn *c);

G_END_DECLS

#endif
