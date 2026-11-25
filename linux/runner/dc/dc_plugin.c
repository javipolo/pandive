// Plugin Linux del ordenador de buceo (ver dc_plugin.h). La descarga es
// bloqueante y corre en un hilo propio; progreso y resultado vuelven al hilo
// principal (la API de Flutter no es thread-safe).
#include "dc_plugin.h"

#include <stdlib.h>

#include "bluez_ble.h"
#include "dc_scanner.h"
#include "pandive_dc_core.h"

static FlEventChannel *progress_channel = NULL;
static gboolean progress_listening = FALSE;

// ---------------------------------------------------------------------------
// Progreso
// ---------------------------------------------------------------------------

typedef struct { int cur, max; } Progress;

static gboolean send_progress(gpointer ud) {
    Progress *p = ud;
    if (progress_listening) {
        g_autoptr(FlValue) m = fl_value_new_map();
        fl_value_set_string_take(m, "current", fl_value_new_int(p->cur));
        fl_value_set_string_take(m, "maximum", fl_value_new_int(p->max));
        fl_event_channel_send(progress_channel, m, NULL, NULL);
    }
    return G_SOURCE_REMOVE;
}

static FlMethodErrorResponse *progress_listen(FlEventChannel *c, FlValue *a, gpointer ud) {
    (void) c; (void) a; (void) ud;
    progress_listening = TRUE;
    return NULL;
}

static FlMethodErrorResponse *progress_cancel(FlEventChannel *c, FlValue *a, gpointer ud) {
    (void) c; (void) a; (void) ud;
    progress_listening = FALSE;
    return NULL;
}

// ---------------------------------------------------------------------------
// Descarga (hilo de trabajo)
// ---------------------------------------------------------------------------

typedef struct {
    FlMethodCall *call;
    gchar *vendor, *product, *address, *fingerprint;
    int max_dives;
    gchar *json; // resultado
} Download;

static int io_read(void *ud, unsigned char *buf, size_t cap, int timeout_ms) {
    return ble_conn_read(ud, buf, cap, timeout_ms);
}

static int io_write(void *ud, const void *data, size_t size) {
    return ble_conn_write(ud, data, size);
}

static void io_progress(void *ud, int cur, int max) {
    (void) ud;
    Progress *p = g_new(Progress, 1);
    p->cur = cur;
    p->max = max;
    g_main_context_invoke_full(NULL, G_PRIORITY_DEFAULT, send_progress, p, g_free);
}

static gboolean finish_download(gpointer ud) {
    Download *d = ud;
    g_autoptr(FlValue) r = fl_value_new_string(d->json);
    fl_method_call_respond_success(d->call, r, NULL);
    g_object_unref(d->call);
    g_free(d->vendor); g_free(d->product); g_free(d->address); g_free(d->fingerprint);
    g_free(d->json);
    g_free(d);
    return G_SOURCE_REMOVE;
}

static gchar *error_json(const gchar *msg) {
    g_autoptr(GString) s = g_string_new("{\"error\":\"");
    for (const gchar *p = msg; *p; p++)
        g_string_append_c(s, (*p == '"' || *p == '\\') ? '\'' : *p);
    g_string_append(s, "\"}");
    return g_strdup(s->str);
}

static gpointer download_thread(gpointer ud) {
    Download *d = ud;
    g_autofree gchar *err = NULL;
    BleConn *c = ble_conn_open(d->address, 20000, &err);
    if (!c) {
        d->json = error_json(err ? err : "could not connect");
    } else {
        pdc_io_t io = { io_read, io_write, io_progress, c };
        char *json = pdc_download(d->vendor, d->product, d->fingerprint, d->max_dives, &io);
        d->json = g_strdup(json);
        free(json);
        ble_conn_close(c);
    }
    g_main_context_invoke(NULL, finish_download, d);
    return NULL;
}

static gchar *arg_string(FlValue *args, const gchar *key) {
    FlValue *v = args ? fl_value_lookup_string(args, key) : NULL;
    return g_strdup(v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING
                        ? fl_value_get_string(v) : "");
}

static void start_download(FlMethodCall *call) {
    FlValue *args = fl_method_call_get_args(call);
    Download *d = g_new0(Download, 1);
    d->call = g_object_ref(call);
    d->vendor = arg_string(args, "vendor");
    d->product = arg_string(args, "product");
    d->address = arg_string(args, "address");
    d->fingerprint = arg_string(args, "fingerprint");
    FlValue *m = args ? fl_value_lookup_string(args, "maxDives") : NULL;
    d->max_dives = m && fl_value_get_type(m) == FL_VALUE_TYPE_INT ? (int) fl_value_get_int(m) : 0;
    g_thread_unref(g_thread_new("pandive-dc", download_thread, d));
}

// ---------------------------------------------------------------------------
// MethodChannel pandive/dc
// ---------------------------------------------------------------------------

static gboolean bt_powered(void) {
    g_autoptr(GDBusConnection) bus = g_bus_get_sync(G_BUS_TYPE_SYSTEM, NULL, NULL);
    gboolean powered = FALSE;
    g_autofree gchar *ad = bus ? bluez_adapter_path(bus, &powered) : NULL;
    return ad && powered;
}

static void on_method(FlMethodChannel *ch, FlMethodCall *call, gpointer ud) {
    (void) ch; (void) ud;
    const gchar *name = fl_method_call_get_name(call);
    if (g_strcmp0(name, "matchName") == 0) {
        g_autofree gchar *n = arg_string(fl_method_call_get_args(call), "name");
        char *m = pdc_match_name(n);
        g_autoptr(FlValue) r = fl_value_new_string(m);
        free(m);
        fl_method_call_respond_success(call, r, NULL);
    } else if (g_strcmp0(name, "btEnabled") == 0) {
        g_autoptr(FlValue) r = fl_value_new_bool(bt_powered());
        fl_method_call_respond_success(call, r, NULL);
    } else if (g_strcmp0(name, "enableBt") == 0) {
        g_autoptr(GDBusConnection) bus = g_bus_get_sync(G_BUS_TYPE_SYSTEM, NULL, NULL);
        if (bus) bluez_power_on(bus);
        fl_method_call_respond_success(call, NULL, NULL);
    } else if (g_strcmp0(name, "download") == 0) {
        start_download(call);
    } else {
        fl_method_call_respond_not_implemented(call, NULL);
    }
}

void dc_plugin_register_with_registrar(FlPluginRegistrar *registrar) {
    FlBinaryMessenger *messenger = fl_plugin_registrar_get_messenger(registrar);
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    // Los canales viven lo que la app: no se liberan.
    FlMethodChannel *mc = fl_method_channel_new(messenger, "pandive/dc", FL_METHOD_CODEC(codec));
    fl_method_channel_set_method_call_handler(mc, on_method, NULL, NULL);
    progress_channel =
        fl_event_channel_new(messenger, "pandive/dc/progress", FL_METHOD_CODEC(codec));
    fl_event_channel_set_stream_handlers(progress_channel, progress_listen, progress_cancel,
                                         NULL, NULL);
    dc_scanner_register(messenger);
}
