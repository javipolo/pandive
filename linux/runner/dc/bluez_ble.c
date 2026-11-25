// GATT connection with BlueZ over D-Bus (see bluez_ble.h). Same criteria as
// BleConnection.kt: preferred serial service (Shearwater, Mares) or the first
// with a write characteristic and a notify one; OSTC (Telit)
// with credit-based flow control.
#include "bluez_ble.h"

#include <string.h>
#include <strings.h>

#define BLUEZ "org.bluez"
#define IFACE_ADAPTER "org.bluez.Adapter1"
#define IFACE_DEVICE "org.bluez.Device1"
#define IFACE_CHAR "org.bluez.GattCharacteristic1"
#define IFACE_PROPS "org.freedesktop.DBus.Properties"

static const char *PREFERRED_SERVICES[] = {
    "fe25c237-0ece-443c-b0aa-e02033e7029d", // Shearwater Petrel/Perdix/Peregrine/Tern
    "1aa44039-1667-4b29-87cc-dfecaaf31d97", // Shearwater Perdix 3
    "544e326b-5b72-c6b0-1c46-41c1bc448118", // Mares BlueLink
};
#define HW_TELIT_SERVICE "0000fefb-0000-1000-8000-00805f9b34fb"
#define T_DATA_TX "00000002-0000-1000-8000-008025000000"
#define T_DATA_RX "00000001-0000-1000-8000-008025000000"
#define T_CRED_TX "00000004-0000-1000-8000-008025000000"
#define T_CRED_RX "00000003-0000-1000-8000-008025000000"
#define MAX_CREDIT 254
#define MIN_CREDIT 32

static const char *KEYWORDS[] = {
    "peregrine", "perdix", "petrel", "teric", "nerd", "tern", // Shearwater
    "mares", "puck", "quad", "genius", "sirius",               // Mares
    "suunto", "eon", "d5",                                     // Suunto
    "shearwater", "garmin", "descent", "oceanic", "aqualung",
    "scubapro", "galileo", "ratio", "divesoft",
    "ostc", "hw ", "heinrichs", "mclean", "cressi", "deepblu", "cosmiq",
};

gboolean bluez_likely_dive_computer(const gchar *name) {
    g_autofree gchar *n = g_utf8_strdown(name, -1);
    for (gsize i = 0; i < G_N_ELEMENTS(KEYWORDS); i++)
        if (strstr(n, KEYWORDS[i])) return TRUE;
    return FALSE;
}

static GVariant *managed_objects(GDBusConnection *bus) {
    return g_dbus_connection_call_sync(bus, BLUEZ, "/",
        "org.freedesktop.DBus.ObjectManager", "GetManagedObjects", NULL,
        G_VARIANT_TYPE("(a{oa{sa{sv}}})"), G_DBUS_CALL_FLAGS_NONE, 5000, NULL, NULL);
}

gchar *bluez_adapter_path(GDBusConnection *bus, gboolean *powered) {
    g_autoptr(GVariant) res = managed_objects(bus);
    if (!res) return NULL;
    g_autoptr(GVariant) objs = g_variant_get_child_value(res, 0);
    GVariantIter it;
    const gchar *path;
    GVariant *ifaces;
    g_variant_iter_init(&it, objs);
    while (g_variant_iter_next(&it, "{&o@a{sa{sv}}}", &path, &ifaces)) {
        g_autoptr(GVariant) props =
            g_variant_lookup_value(ifaces, IFACE_ADAPTER, G_VARIANT_TYPE("a{sv}"));
        g_variant_unref(ifaces);
        if (!props) continue;
        if (powered) {
            gboolean p = FALSE;
            g_variant_lookup(props, "Powered", "b", &p);
            *powered = p;
        }
        return g_strdup(path);
    }
    return NULL;
}

void bluez_power_on(GDBusConnection *bus) {
    g_autofree gchar *ad = bluez_adapter_path(bus, NULL);
    if (!ad) return;
    g_autoptr(GVariant) r = g_dbus_connection_call_sync(bus, BLUEZ, ad, IFACE_PROPS,
        "Set", g_variant_new("(ssv)", IFACE_ADAPTER, "Powered", g_variant_new_boolean(TRUE)),
        NULL, G_DBUS_CALL_FLAGS_NONE, 5000, NULL, NULL);
}

// ---------------------------------------------------------------------------

struct _BleConn {
    GMainContext *ctx;
    GDBusConnection *bus;
    gchar *dev_path;
    gchar *write_path, *notify_path;
    gboolean write_cmd;             // write-without-response
    gboolean credit;                // OSTC Telit
    gchar *cred_tx_path, *cred_rx_path;
    int balance;
    guint sub_char, sub_dev;
    GQueue queue;                   // GBytes* recibidos
    gboolean disconnected;
};

// Finds the Device1 object with that MAC; returns its path or NULL.
static gchar *find_device(GDBusConnection *bus, const gchar *address) {
    g_autoptr(GVariant) res = managed_objects(bus);
    if (!res) return NULL;
    g_autoptr(GVariant) objs = g_variant_get_child_value(res, 0);
    GVariantIter it;
    const gchar *path;
    GVariant *ifaces;
    gchar *found = NULL;
    g_variant_iter_init(&it, objs);
    while (!found && g_variant_iter_next(&it, "{&o@a{sa{sv}}}", &path, &ifaces)) {
        g_autoptr(GVariant) props =
            g_variant_lookup_value(ifaces, IFACE_DEVICE, G_VARIANT_TYPE("a{sv}"));
        const gchar *addr = NULL;
        if (props && g_variant_lookup(props, "Address", "&s", &addr) &&
            g_ascii_strcasecmp(addr, address) == 0)
            found = g_strdup(path);
        g_variant_unref(ifaces);
    }
    return found;
}

static GVariant *call(BleConn *c, const gchar *path, const gchar *iface,
                      const gchar *method, GVariant *args, int timeout, GError **err) {
    return g_dbus_connection_call_sync(c->bus, BLUEZ, path, iface, method, args,
                                       NULL, G_DBUS_CALL_FLAGS_NONE, timeout, NULL, err);
}

static gboolean device_bool(BleConn *c, const gchar *prop) {
    g_autoptr(GVariant) r = call(c, c->dev_path, IFACE_PROPS, "Get",
                                 g_variant_new("(ss)", IFACE_DEVICE, prop), 3000, NULL);
    if (!r) return FALSE;
    g_autoptr(GVariant) v = NULL;
    g_variant_get(r, "(v)", &v);
    return g_variant_is_of_type(v, G_VARIANT_TYPE_BOOLEAN) && g_variant_get_boolean(v);
}

static GVariant *discovery_filter(void) {
    GVariantBuilder b;
    g_variant_builder_init(&b, G_VARIANT_TYPE("a{sv}"));
    g_variant_builder_add(&b, "{sv}", "Transport", g_variant_new_string("le"));
    return g_variant_new("(a{sv})", &b);
}

// If BlueZ doesn't know the device yet, discover until it shows up.
static gchar *discover_device(GDBusConnection *bus, const gchar *address, int timeout_ms) {
    gchar *path = find_device(bus, address);
    if (path) return path;
    g_autofree gchar *ad = bluez_adapter_path(bus, NULL);
    if (!ad) return NULL;
    g_autoptr(GVariant) f = g_dbus_connection_call_sync(bus, BLUEZ, ad, IFACE_ADAPTER,
        "SetDiscoveryFilter", discovery_filter(), NULL, G_DBUS_CALL_FLAGS_NONE, 3000, NULL, NULL);
    g_autoptr(GVariant) s = g_dbus_connection_call_sync(bus, BLUEZ, ad, IFACE_ADAPTER,
        "StartDiscovery", NULL, NULL, G_DBUS_CALL_FLAGS_NONE, 3000, NULL, NULL);
    gint64 end = g_get_monotonic_time() + (gint64) timeout_ms * 1000;
    while (!path && g_get_monotonic_time() < end) {
        g_usleep(300 * 1000);
        path = find_device(bus, address);
    }
    if (s) {
        g_autoptr(GVariant) r = g_dbus_connection_call_sync(bus, BLUEZ, ad, IFACE_ADAPTER,
            "StopDiscovery", NULL, NULL, G_DBUS_CALL_FLAGS_NONE, 3000, NULL, NULL);
    }
    return path;
}

// ---------------------------------------------------------------------------
// GATT characteristic selection
// ---------------------------------------------------------------------------

typedef struct { gchar *path, *uuid, *service; gboolean w, wnr, n; } GattChar;

static void gatt_char_free(gpointer p) {
    GattChar *g = p;
    g_free(g->path); g_free(g->uuid); g_free(g->service); g_free(g);
}

// Services (path -> uuid) and characteristics under the device.
static void list_gatt(BleConn *c, GHashTable *services, GPtrArray *chars) {
    g_autoptr(GVariant) res = managed_objects(c->bus);
    if (!res) return;
    g_autoptr(GVariant) objs = g_variant_get_child_value(res, 0);
    g_autofree gchar *prefix = g_strconcat(c->dev_path, "/", NULL);
    GVariantIter it;
    const gchar *path;
    GVariant *ifaces;
    g_variant_iter_init(&it, objs);
    while (g_variant_iter_next(&it, "{&o@a{sa{sv}}}", &path, &ifaces)) {
        if (g_str_has_prefix(path, prefix)) {
            g_autoptr(GVariant) sp = g_variant_lookup_value(ifaces,
                "org.bluez.GattService1", G_VARIANT_TYPE("a{sv}"));
            g_autoptr(GVariant) cp = g_variant_lookup_value(ifaces,
                IFACE_CHAR, G_VARIANT_TYPE("a{sv}"));
            const gchar *uuid = NULL, *svc = NULL;
            if (sp && g_variant_lookup(sp, "UUID", "&s", &uuid))
                g_hash_table_insert(services, g_strdup(path), g_ascii_strdown(uuid, -1));
            if (cp && g_variant_lookup(cp, "UUID", "&s", &uuid) &&
                g_variant_lookup(cp, "Service", "&o", &svc)) {
                GattChar *g = g_new0(GattChar, 1);
                g->path = g_strdup(path);
                g->uuid = g_ascii_strdown(uuid, -1);
                g->service = g_strdup(svc);
                g_autofree const gchar **flags = NULL;
                if (g_variant_lookup(cp, "Flags", "^a&s", &flags)) {
                    for (int i = 0; flags[i]; i++) {
                        if (!strcmp(flags[i], "write")) g->w = TRUE;
                        if (!strcmp(flags[i], "write-without-response")) g->wnr = TRUE;
                        if (!strcmp(flags[i], "notify") || !strcmp(flags[i], "indicate"))
                            g->n = TRUE;
                    }
                }
                g_ptr_array_add(chars, g);
            }
        }
        g_variant_unref(ifaces);
    }
}

static GattChar *char_by_uuid(GPtrArray *chars, const gchar *svc, const gchar *uuid) {
    for (guint i = 0; i < chars->len; i++) {
        GattChar *g = chars->pdata[i];
        if (!strcmp(g->service, svc) && !strcmp(g->uuid, uuid)) return g;
    }
    return NULL;
}

// First write + first notify of service svc.
static gboolean pick_in_service(BleConn *c, GPtrArray *chars, const gchar *svc) {
    GattChar *w = NULL, *n = NULL;
    for (guint i = 0; i < chars->len; i++) {
        GattChar *g = chars->pdata[i];
        if (strcmp(g->service, svc)) continue;
        if (!w && (g->w || g->wnr)) w = g;
        if (!n && g->n) n = g;
    }
    if (!w || !n) return FALSE;
    c->write_path = g_strdup(w->path);
    c->write_cmd = w->wnr;
    c->notify_path = g_strdup(n->path);
    g_message("PandiveBLE: servicio %s write=%s notify=%s", svc, w->uuid, n->uuid);
    return TRUE;
}

static gboolean select_chars(BleConn *c, GHashTable *services, GPtrArray *chars) {
    GHashTableIter hi;
    gpointer k, v;
    // OSTC Telit: 4 fixed characteristics with credits.
    g_hash_table_iter_init(&hi, services);
    while (g_hash_table_iter_next(&hi, &k, &v)) {
        if (strcmp(v, HW_TELIT_SERVICE)) continue;
        GattChar *dtx = char_by_uuid(chars, k, T_DATA_TX), *drx = char_by_uuid(chars, k, T_DATA_RX);
        GattChar *ctx = char_by_uuid(chars, k, T_CRED_TX), *crx = char_by_uuid(chars, k, T_CRED_RX);
        if (dtx && drx && ctx && crx) {
            c->credit = TRUE;
            c->notify_path = g_strdup(dtx->path);
            c->write_path = g_strdup(drx->path);
            c->write_cmd = drx->wnr && !drx->w;
            c->cred_tx_path = g_strdup(ctx->path);
            c->cred_rx_path = g_strdup(crx->path);
            g_message("PandiveBLE: OSTC Telit, credit-based flow control");
            return TRUE;
        }
    }
    for (gsize p = 0; p < G_N_ELEMENTS(PREFERRED_SERVICES); p++) {
        g_hash_table_iter_init(&hi, services);
        while (g_hash_table_iter_next(&hi, &k, &v))
            if (!strcmp(v, PREFERRED_SERVICES[p]) && pick_in_service(c, chars, k)) return TRUE;
    }
    g_hash_table_iter_init(&hi, services);
    while (g_hash_table_iter_next(&hi, &k, &v))
        if (pick_in_service(c, chars, k)) return TRUE;
    return FALSE;
}

// ---------------------------------------------------------------------------
// Notifications and writing
// ---------------------------------------------------------------------------

static int write_value(BleConn *c, const gchar *path, const void *data, gsize size,
                       gboolean command) {
    GVariantBuilder opts;
    g_variant_builder_init(&opts, G_VARIANT_TYPE("a{sv}"));
    g_variant_builder_add(&opts, "{sv}", "type",
                          g_variant_new_string(command ? "command" : "request"));
    GVariant *val = g_variant_new_fixed_array(G_VARIANT_TYPE_BYTE, data, size, 1);
    g_autoptr(GError) err = NULL;
    g_autoptr(GVariant) r = call(c, path, IFACE_CHAR, "WriteValue",
                                 g_variant_new("(@aya{sv})", val, &opts), 5000, &err);
    if (!r) g_warning("PandiveBLE: WriteValue: %s", err->message);
    return r ? 0 : -1;
}

static void write_credit(BleConn *c, int n) {
    guint8 b = (guint8) n;
    write_value(c, c->cred_rx_path, &b, 1, FALSE);
}

static void on_char_changed(GDBusConnection *bus, const gchar *sender, const gchar *path,
                            const gchar *iface, const gchar *signal, GVariant *params,
                            gpointer ud) {
    (void) bus; (void) sender; (void) iface; (void) signal;
    BleConn *c = ud;
    gboolean data = !g_strcmp0(path, c->notify_path);
    gboolean cred = c->credit && !g_strcmp0(path, c->cred_tx_path);
    if (!data && !cred) return;
    g_autoptr(GVariant) changed = g_variant_get_child_value(params, 1);
    g_autoptr(GVariant) v = g_variant_lookup_value(changed, "Value", G_VARIANT_TYPE("ay"));
    if (!v) return;
    gsize n = 0;
    const guint8 *bytes = g_variant_get_fixed_array(v, &n, 1);
    if (cred) {
        if (n > 0) c->balance += bytes[0];
        return;
    }
    g_queue_push_tail(&c->queue, g_bytes_new(bytes, n));
    if (c->credit && --c->balance <= MIN_CREDIT) {
        c->balance += MAX_CREDIT - MIN_CREDIT;
        write_credit(c, MAX_CREDIT - MIN_CREDIT);
    }
}

static void on_dev_changed(GDBusConnection *bus, const gchar *sender, const gchar *path,
                           const gchar *iface, const gchar *signal, GVariant *params,
                           gpointer ud) {
    (void) bus; (void) sender; (void) path; (void) iface; (void) signal;
    BleConn *c = ud;
    g_autoptr(GVariant) changed = g_variant_get_child_value(params, 1);
    gboolean connected = TRUE;
    if (g_variant_lookup(changed, "Connected", "b", &connected) && !connected)
        c->disconnected = TRUE;
}

static gboolean auth_error(const GError *e) {
    return e && (strstr(e->message, "NotPermitted") || strstr(e->message, "NotAuthorized") ||
                 strstr(e->message, "Authentication") || strstr(e->message, "Insufficient"));
}

// StartNotify; if it fails for security, pair (the desktop agent
// asks for the PIN if needed) and retry.
static gboolean start_notify(BleConn *c, const gchar *path, gchar **error) {
    g_autoptr(GError) err = NULL;
    g_autoptr(GVariant) r = call(c, path, IFACE_CHAR, "StartNotify", NULL, 10000, &err);
    if (!r && auth_error(err)) {
        g_message("PandiveBLE: StartNotify pide seguridad (%s); emparejando", err->message);
        g_clear_error(&err);
        g_autoptr(GVariant) p = call(c, c->dev_path, IFACE_DEVICE, "Pair", NULL, 60000, &err);
        if (p || (err && strstr(err->message, "AlreadyExists"))) {
            g_clear_error(&err);
            r = call(c, path, IFACE_CHAR, "StartNotify", NULL, 10000, &err);
        }
    }
    if (!r) *error = g_strdup_printf("Could not enable notifications: %s", err->message);
    return r != NULL;
}

static gboolean wake(gpointer ud) { (void) ud; return G_SOURCE_REMOVE; }

static gboolean wait_resolved(BleConn *c, int timeout_ms) {
    gint64 end = g_get_monotonic_time() + (gint64) timeout_ms * 1000;
    while (g_get_monotonic_time() < end) {
        if (device_bool(c, "ServicesResolved")) return TRUE;
        g_usleep(100 * 1000);
    }
    return FALSE;
}

static gboolean do_connect(BleConn *c, int timeout_ms, gchar **error) {
    for (int attempt = 0; attempt < 2; attempt++) {
        g_autoptr(GError) err = NULL;
        g_autoptr(GVariant) r = call(c, c->dev_path, IFACE_DEVICE, "Connect", NULL,
                                     timeout_ms, &err);
        if (r || (err && strstr(err->message, "AlreadyConnected"))) return TRUE;
        g_warning("PandiveBLE: Connect (intento %d): %s", attempt + 1, err->message);
        if (attempt == 1) *error = g_strdup_printf("Could not connect: %s", err->message);
        g_usleep(1000 * 1000);
    }
    return FALSE;
}

BleConn *ble_conn_open(const gchar *address, int timeout_ms, gchar **error) {
    BleConn *c = g_new0(BleConn, 1);
    // declared before any goto (automatic cleanup on exit)
    g_autoptr(GHashTable) services =
        g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
    g_autoptr(GPtrArray) chars = g_ptr_array_new_with_free_func(gatt_char_free);
    g_queue_init(&c->queue);
    c->ctx = g_main_context_new();
    g_main_context_push_thread_default(c->ctx);
    g_autoptr(GError) err = NULL;
    c->bus = g_bus_get_sync(G_BUS_TYPE_SYSTEM, NULL, &err);
    if (!c->bus) {
        *error = g_strdup_printf("No D-Bus access: %s", err->message);
        goto fail;
    }
    c->dev_path = discover_device(c->bus, address, 15000);
    if (!c->dev_path) { *error = g_strdup("Device not found"); goto fail; }
    if (!do_connect(c, timeout_ms, error)) goto fail;
    if (!wait_resolved(c, 15000)) { *error = g_strdup("Timed out discovering services"); goto fail; }

    list_gatt(c, services, chars);
    if (!select_chars(c, services, chars)) {
        *error = g_strdup("No read/write characteristic found");
        goto fail;
    }

    // Subscriptions (dispatched on c->ctx, this thread's context).
    c->sub_char = g_dbus_connection_signal_subscribe(c->bus, BLUEZ, IFACE_PROPS,
        "PropertiesChanged", NULL, IFACE_CHAR, G_DBUS_SIGNAL_FLAGS_NONE,
        on_char_changed, c, NULL);
    c->sub_dev = g_dbus_connection_signal_subscribe(c->bus, BLUEZ, IFACE_PROPS,
        "PropertiesChanged", c->dev_path, IFACE_DEVICE, G_DBUS_SIGNAL_FLAGS_NONE,
        on_dev_changed, c, NULL);

    if (c->credit) {
        // Telit sequence: credits (indicate) -> data (notify) -> initial credit.
        if (!start_notify(c, c->cred_tx_path, error)) goto fail;
        if (!start_notify(c, c->notify_path, error)) goto fail;
        c->balance = MAX_CREDIT;
        write_credit(c, MAX_CREDIT);
    } else if (!start_notify(c, c->notify_path, error)) {
        goto fail;
    }
    return c;

fail:
    ble_conn_close(c);
    return NULL;
}

int ble_conn_read(BleConn *c, unsigned char *buf, gsize cap, int timeout_ms) {
    gint64 end = g_get_monotonic_time() + (gint64) timeout_ms * 1000;
    while (g_queue_is_empty(&c->queue)) {
        // handle signals already received before checking the clock or the connection
        while (g_main_context_iteration(c->ctx, FALSE)) {}
        if (!g_queue_is_empty(&c->queue)) break;
        if (c->disconnected) return -1;
        gint64 left = end - g_get_monotonic_time();
        if (left <= 0) return 0;
        GSource *t = g_timeout_source_new((guint) (left / 1000) + 1);
        g_source_set_callback(t, wake, NULL, NULL);
        g_source_attach(t, c->ctx);
        g_main_context_iteration(c->ctx, TRUE);
        g_source_destroy(t);
        g_source_unref(t);
    }
    GBytes *b = g_queue_pop_head(&c->queue);
    gsize n = 0;
    const guint8 *d = g_bytes_get_data(b, &n);
    if (n > cap) n = cap;
    memcpy(buf, d, n);
    g_bytes_unref(b);
    return (int) n;
}

int ble_conn_write(BleConn *c, const void *data, gsize size) {
    if (c->disconnected) return -1;
    return write_value(c, c->write_path, data, size, c->write_cmd);
}

void ble_conn_close(BleConn *c) {
    if (!c) return;
    if (c->bus) {
        if (c->sub_char) g_dbus_connection_signal_unsubscribe(c->bus, c->sub_char);
        if (c->sub_dev) g_dbus_connection_signal_unsubscribe(c->bus, c->sub_dev);
        if (c->dev_path) {
            g_autoptr(GVariant) r = call(c, c->dev_path, IFACE_DEVICE, "Disconnect",
                                         NULL, 5000, NULL);
        }
        g_object_unref(c->bus);
    }
    g_queue_clear_full(&c->queue, (GDestroyNotify) g_bytes_unref);
    while (g_main_context_iteration(c->ctx, FALSE)) {}
    g_main_context_pop_thread_default(c->ctx);
    g_main_context_unref(c->ctx);
    g_free(c->dev_path); g_free(c->write_path); g_free(c->notify_path);
    g_free(c->cred_tx_path); g_free(c->cred_rx_path);
    g_free(c);
}
