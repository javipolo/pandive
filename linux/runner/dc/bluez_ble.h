// BLE over BlueZ (D-Bus, GIO): adapter, scan and a GATT connection
// exposed as a synchronous packet stream for libdivecomputer. Equivalent to
// Android's BleScanner/BleConnection.
#ifndef PANDIVE_BLUEZ_BLE_H
#define PANDIVE_BLUEZ_BLE_H

#include <gio/gio.h>

G_BEGIN_DECLS

// Path of the first adapter ("/org/bluez/hci0") or NULL. powered optional.
gchar *bluez_adapter_path(GDBusConnection *bus, gboolean *powered);

// Powers the adapter on (may fail due to rfkill/polkit; ignored).
void bluez_power_on(GDBusConnection *bus);

// Does the name look like a dive computer? (to highlight it in the scan)
gboolean bluez_likely_dive_computer(const gchar *name);

typedef struct _BleConn BleConn;

// Connects (blocking) to the device with that MAC. Call from a worker
// thread: uses its own GMainContext. NULL + *error on failure.
BleConn *ble_conn_open(const gchar *address, int timeout_ms, gchar **error);

// Next received packet: number of bytes, 0 on timeout, <0 on error.
int ble_conn_read(BleConn *c, unsigned char *buf, gsize cap, int timeout_ms);

// Writes a packet. 0 if ok.
int ble_conn_write(BleConn *c, const void *data, gsize size);

void ble_conn_close(BleConn *c);

G_END_DECLS

#endif
