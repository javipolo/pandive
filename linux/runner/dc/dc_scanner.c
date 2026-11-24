// Escaneo BLE con BlueZ para el EventChannel pandive/dc/scan. Emite un mapa
// {name, id, rssi, likely} por dispositivo visto (como BleScanner.kt).
// Corre en el hilo principal (contexto GLib por defecto).
#include "dc_scanner.h"

#include <string.h>

#include "bluez_ble.h"

#define BLUEZ "org.bluez"
#define IFACE_DEVICE "org.bluez.Device1"

struct _DcScanner {
    FlEventChannel *channel;
    GDBusConnection *bus;
    gchar *adapter;
    guint sub_added, sub_changed;
    gboolean discovering;
};

// Emite el dispositivo si tiene nombre y RSSI (=visto en este escaneo).
static void emit_props(DcScanner *s, GVariant *props) {
    const gchar *name = NULL, *addr = NULL;
    gint16 rssi = 0;
    if (!g_variant_lookup(props, "Name", "&s", &name) || !*name) return;
    if (!g_variant_lookup(props, "Address", "&s", &addr)) return;
    if (!g_variant_lookup(props, "RSSI", "n", &rssi)) return;
    g_autoptr(FlValue) m = fl_value_new_map();
    fl_value_set_string_take(m, "name", fl_value_new_string(name));
    fl_value_set_string_take(m, "id", fl_value_new_string(addr));
    fl_value_set_string_take(m, "rssi", fl_value_new_int(rssi));
    fl_value_set_string_take(m, "likely", fl_value_new_bool(bluez_likely_dive_computer(name)));
    fl_event_channel_send(s->channel, m, NULL, NULL);
}

static void emit_path(DcScanner *s, const gchar *path) {
    g_autoptr(GVariant) r = g_dbus_connection_call_sync(s->bus, BLUEZ, path,
        "org.freedesktop.DBus.Properties", "GetAll", g_variant_new("(s)", IFACE_DEVICE),
        G_VARIANT_TYPE("(a{sv})"), G_DBUS_CALL_FLAGS_NONE, 2000, NULL, NULL);
    if (!r) return;
    g_autoptr(GVariant) props = g_variant_get_child_value(r, 0);
    emit_props(s, props);
}

static void on_added(GDBusConnection *bus, const gchar *sender, const gchar *path,
                     const gchar *iface, const gchar *signal, GVariant *params, gpointer ud) {
    (void) bus; (void) sender; (void) path; (void) iface; (void) signal;
    const gchar *obj = NULL;
    g_autoptr(GVariant) ifaces = NULL;
    g_variant_get(params, "(&o@a{sa{sv}})", &obj, &ifaces);
    g_autoptr(GVariant) props =
        g_variant_lookup_value(ifaces, IFACE_DEVICE, G_VARIANT_TYPE("a{sv}"));
    if (props) emit_props(ud, props);
}

static void on_changed(GDBusConnection *bus, const gchar *sender, const gchar *path,
                       const gchar *iface, const gchar *signal, GVariant *params, gpointer ud) {
    (void) bus; (void) sender; (void) iface; (void) signal; (void) params;
    emit_path(ud, path); // RSSI/nombre actualizados: releer y emitir
}

// Dispositivos ya conocidos y vistos recientemente (con RSSI).
static void emit_known(DcScanner *s) {
    g_autoptr(GVariant) res = g_dbus_connection_call_sync(s->bus, BLUEZ, "/",
        "org.freedesktop.DBus.ObjectManager", "GetManagedObjects", NULL,
        G_VARIANT_TYPE("(a{oa{sa{sv}}})"), G_DBUS_CALL_FLAGS_NONE, 5000, NULL, NULL);
    if (!res) return;
    g_autoptr(GVariant) objs = g_variant_get_child_value(res, 0);
    GVariantIter it;
    const gchar *path;
    GVariant *ifaces;
    g_variant_iter_init(&it, objs);
    while (g_variant_iter_next(&it, "{&o@a{sa{sv}}}", &path, &ifaces)) {
        g_autoptr(GVariant) props =
            g_variant_lookup_value(ifaces, IFACE_DEVICE, G_VARIANT_TYPE("a{sv}"));
        if (props) emit_props(s, props);
        g_variant_unref(ifaces);
    }
}

static void stop(DcScanner *s) {
    if (s->sub_added) g_dbus_connection_signal_unsubscribe(s->bus, s->sub_added);
    if (s->sub_changed) g_dbus_connection_signal_unsubscribe(s->bus, s->sub_changed);
    s->sub_added = s->sub_changed = 0;
    if (s->discovering) {
        g_autoptr(GVariant) r = g_dbus_connection_call_sync(s->bus, BLUEZ, s->adapter,
            "org.bluez.Adapter1", "StopDiscovery", NULL, NULL, G_DBUS_CALL_FLAGS_NONE,
            3000, NULL, NULL);
        s->discovering = FALSE;
    }
    g_clear_pointer(&s->adapter, g_free);
    g_clear_object(&s->bus);
}

static FlMethodErrorResponse *on_listen(FlEventChannel *ch, FlValue *args, gpointer ud) {
    (void) ch; (void) args;
    DcScanner *s = ud;
    stop(s);
    g_autoptr(GError) err = NULL;
    s->bus = g_bus_get_sync(G_BUS_TYPE_SYSTEM, NULL, &err);
    if (!s->bus) return fl_method_error_response_new("no_scanner", err->message, NULL);
    gboolean powered = FALSE;
    s->adapter = bluez_adapter_path(s->bus, &powered);
    if (!s->adapter)
        return fl_method_error_response_new("no_scanner", "No hay adaptador Bluetooth", NULL);
    if (!powered)
        return fl_method_error_response_new("bt_off", "Bluetooth desactivado", NULL);

    s->sub_added = g_dbus_connection_signal_subscribe(s->bus, BLUEZ,
        "org.freedesktop.DBus.ObjectManager", "InterfacesAdded", "/", NULL,
        G_DBUS_SIGNAL_FLAGS_NONE, on_added, s, NULL);
    s->sub_changed = g_dbus_connection_signal_subscribe(s->bus, BLUEZ,
        "org.freedesktop.DBus.Properties", "PropertiesChanged", NULL, IFACE_DEVICE,
        G_DBUS_SIGNAL_FLAGS_NONE, on_changed, s, NULL);

    GVariantBuilder b;
    g_variant_builder_init(&b, G_VARIANT_TYPE("a{sv}"));
    g_variant_builder_add(&b, "{sv}", "Transport", g_variant_new_string("le"));
    g_variant_builder_add(&b, "{sv}", "DuplicateData", g_variant_new_boolean(TRUE));
    g_autoptr(GVariant) f = g_dbus_connection_call_sync(s->bus, BLUEZ, s->adapter,
        "org.bluez.Adapter1", "SetDiscoveryFilter", g_variant_new("(a{sv})", &b), NULL,
        G_DBUS_CALL_FLAGS_NONE, 3000, NULL, NULL);
    g_autoptr(GVariant) r = g_dbus_connection_call_sync(s->bus, BLUEZ, s->adapter,
        "org.bluez.Adapter1", "StartDiscovery", NULL, NULL, G_DBUS_CALL_FLAGS_NONE,
        3000, NULL, &err);
    if (!r && !strstr(err->message, "InProgress")) {
        g_autofree gchar *msg = g_strdup(err->message);
        stop(s);
        return fl_method_error_response_new("scan_failed", msg, NULL);
    }
    s->discovering = r != NULL;
    emit_known(s);
    return NULL;
}

static FlMethodErrorResponse *on_cancel(FlEventChannel *ch, FlValue *args, gpointer ud) {
    (void) ch; (void) args;
    stop(ud);
    return NULL;
}

static void scanner_free(gpointer ud) {
    DcScanner *s = ud;
    stop(s);
    g_free(s);
}

void dc_scanner_register(FlBinaryMessenger *messenger) {
    DcScanner *s = g_new0(DcScanner, 1);
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    s->channel = fl_event_channel_new(messenger, "pandive/dc/scan", FL_METHOD_CODEC(codec));
    fl_event_channel_set_stream_handlers(s->channel, on_listen, on_cancel, s, scanner_free);
}
