// Puente JNI sobre libdivecomputer.
//  - nativeSupportedCount / nativeSupportedList: capacidad (verifica el enlace).
//  - nativeDownload: conecta por BLE (I/O delegado en BleConnection de Kotlin),
//    recorre las inmersiones, las parsea y las devuelve como JSON.
#include <jni.h>
#include <string.h>
#include <strings.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <android/log.h>

#include <libdivecomputer/common.h>
#include <libdivecomputer/context.h>
#include <libdivecomputer/descriptor.h>
#include <libdivecomputer/iterator.h>
#include <libdivecomputer/custom.h>
#include <libdivecomputer/iostream.h>
#include <libdivecomputer/device.h>
#include <libdivecomputer/parser.h>

#define LOG(...) __android_log_print(ANDROID_LOG_INFO, "PandiveDC", __VA_ARGS__)

// ---------------------------------------------------------------------------
// Capacidad
// ---------------------------------------------------------------------------

JNIEXPORT jint JNICALL
Java_org_drslump_pandive_DiveComputer_nativeSupportedCount(JNIEnv *env, jobject thiz) {
    (void) env; (void) thiz;
    dc_iterator_t *it = NULL;
    if (dc_descriptor_iterator(&it) != DC_STATUS_SUCCESS) return -1;
    jint n = 0;
    dc_descriptor_t *desc = NULL;
    while (dc_iterator_next(it, &desc) == DC_STATUS_SUCCESS) { n++; dc_descriptor_free(desc); }
    dc_iterator_free(it);
    return n;
}

JNIEXPORT jstring JNICALL
Java_org_drslump_pandive_DiveComputer_nativeSupportedList(JNIEnv *env, jobject thiz) {
    (void) thiz;
    dc_iterator_t *it = NULL;
    if (dc_descriptor_iterator(&it) != DC_STATUS_SUCCESS)
        return (*env)->NewStringUTF(env, "");
    size_t cap = 8192, len = 0;
    char *buf = malloc(cap);
    if (!buf) { dc_iterator_free(it); return (*env)->NewStringUTF(env, ""); }
    buf[0] = '\0';
    dc_descriptor_t *desc = NULL;
    while (dc_iterator_next(it, &desc) == DC_STATUS_SUCCESS) {
        const char *v = dc_descriptor_get_vendor(desc);
        const char *p = dc_descriptor_get_product(desc);
        if (!v) v = ""; if (!p) p = "";
        size_t need = strlen(v) + strlen(p) + 3;
        if (len + need > cap) {
            cap *= 2; char *nb = realloc(buf, cap);
            if (!nb) { dc_descriptor_free(desc); break; }
            buf = nb;
        }
        len += snprintf(buf + len, cap - len, "%s %s\n", v, p);
        dc_descriptor_free(desc);
    }
    dc_iterator_free(it);
    jstring r = (*env)->NewStringUTF(env, buf);
    free(buf);
    return r;
}

// ---------------------------------------------------------------------------
// Buffer de texto dinámico (para construir el JSON)
// ---------------------------------------------------------------------------

typedef struct { char *p; size_t len, cap; } strbuf_t;

static void sb_init(strbuf_t *s) { s->cap = 4096; s->len = 0; s->p = malloc(s->cap); if (s->p) s->p[0] = '\0'; }
static void sb_free(strbuf_t *s) { free(s->p); s->p = NULL; }
static void sb_ensure(strbuf_t *s, size_t extra) {
    if (s->len + extra + 1 <= s->cap) return;
    while (s->len + extra + 1 > s->cap) s->cap *= 2;
    s->p = realloc(s->p, s->cap);
}
static void sb_puts(strbuf_t *s, const char *t) {
    if (!s->p) return;
    size_t n = strlen(t); sb_ensure(s, n);
    memcpy(s->p + s->len, t, n); s->len += n; s->p[s->len] = '\0';
}
static void sb_fmt(strbuf_t *s, const char *fmt, ...) {
    if (!s->p) return;
    char tmp[256]; va_list ap; va_start(ap, fmt);
    vsnprintf(tmp, sizeof(tmp), fmt, ap); va_end(ap);
    sb_puts(s, tmp);
}

// ---------------------------------------------------------------------------
// I/O personalizado: delega read/write en BleConnection (Kotlin) vía JNI.
// Todo ocurre en el mismo hilo de la llamada nativeDownload, así que el JNIEnv
// es válido durante toda la descarga.
// ---------------------------------------------------------------------------

typedef struct {
    JNIEnv *env;
    jobject conn;        // BleConnection
    jmethodID readM;     // ByteArray? bleRead(int timeoutMs)
    jmethodID writeM;    // boolean bleWrite(ByteArray)
    int timeout;         // ms
    unsigned char buf[1024];
    size_t buflen, bufpos;
} ble_io_t;

static dc_status_t io_set_timeout(void *ud, int timeout) {
    ((ble_io_t *) ud)->timeout = timeout > 0 ? timeout : 3000;
    return DC_STATUS_SUCCESS;
}

static dc_status_t io_read(void *ud, void *data, size_t size, size_t *actual) {
    ble_io_t *io = ud;
    JNIEnv *env = io->env;
    if (io->bufpos >= io->buflen) {
        // sin datos en el búfer local: pedir un paquete al BLE
        int to = io->timeout > 0 ? io->timeout : 3000;
        jbyteArray arr = (jbyteArray) (*env)->CallObjectMethod(env, io->conn, io->readM, to);
        if (arr == NULL) { *actual = 0; return DC_STATUS_TIMEOUT; }
        jsize n = (*env)->GetArrayLength(env, arr);
        if (n > (jsize) sizeof(io->buf)) n = sizeof(io->buf);
        (*env)->GetByteArrayRegion(env, arr, 0, n, (jbyte *) io->buf);
        (*env)->DeleteLocalRef(env, arr);
        io->buflen = n; io->bufpos = 0;
    }
    size_t avail = io->buflen - io->bufpos;
    size_t copy = size < avail ? size : avail;
    memcpy(data, io->buf + io->bufpos, copy);
    io->bufpos += copy;
    *actual = copy;
    return DC_STATUS_SUCCESS;
}

static dc_status_t io_write(void *ud, const void *data, size_t size, size_t *actual) {
    ble_io_t *io = ud;
    JNIEnv *env = io->env;
    jbyteArray arr = (*env)->NewByteArray(env, (jsize) size);
    (*env)->SetByteArrayRegion(env, arr, 0, (jsize) size, (const jbyte *) data);
    jboolean ok = (*env)->CallBooleanMethod(env, io->conn, io->writeM, arr);
    (*env)->DeleteLocalRef(env, arr);
    *actual = size;
    return ok ? DC_STATUS_SUCCESS : DC_STATUS_IO;
}

// ---------------------------------------------------------------------------
// Parseo de muestras del perfil
// ---------------------------------------------------------------------------

typedef struct {
    strbuf_t *sb;
    int first;
    int haveTime, haveDepth, haveTemp, haveDeco;
    unsigned int timeMs;
    double depth, temp, ceiling;
    int ndlMin, ttsMin, gas; // gas se arrastra entre muestras; -1 = desconocido
} sample_ctx_t;

// Muestra: [timeMs, depth, temp|null, ndl|null, tts|null, ceiling, gas|null]
static void flush_sample(sample_ctx_t *c) {
    if (!c->haveTime) return;
    if (!c->first) sb_puts(c->sb, ",");
    c->first = 0;
    sb_fmt(c->sb, "[%u,%.2f,", c->timeMs, c->haveDepth ? c->depth : 0.0);
    if (c->haveTemp) sb_fmt(c->sb, "%.1f,", c->temp); else sb_puts(c->sb, "null,");
    if (c->haveDeco && c->ceiling > 0)
        sb_fmt(c->sb, "null,%d,%.1f,", c->ttsMin, c->ceiling);
    else if (c->haveDeco)
        sb_fmt(c->sb, "%d,null,0,", c->ndlMin);
    else
        sb_puts(c->sb, "null,null,0,");
    if (c->gas >= 0) sb_fmt(c->sb, "%d]", c->gas); else sb_puts(c->sb, "null]");
    c->haveDepth = c->haveTemp = c->haveDeco = 0;
}

static void sample_cb(dc_sample_type_t type, const dc_sample_value_t *value, void *ud) {
    sample_ctx_t *c = ud;
    if (type == DC_SAMPLE_TIME) {
        flush_sample(c);
        c->timeMs = value->time; c->haveTime = 1;
    } else if (type == DC_SAMPLE_DEPTH) {
        c->depth = value->depth; c->haveDepth = 1;
    } else if (type == DC_SAMPLE_TEMPERATURE) {
        c->temp = value->temperature; c->haveTemp = 1;
    } else if (type == DC_SAMPLE_DECO) {
        c->haveDeco = 1;
        if (value->deco.type == DC_DECO_DECOSTOP) {
            c->ceiling = value->deco.depth;
            c->ttsMin = (int) ((value->deco.tts + 30) / 60);
            c->ndlMin = 0;
        } else { // NDL (y safety/deep stop: sin techo obligatorio)
            c->ceiling = 0;
            c->ndlMin = (int) ((value->deco.time + 30) / 60);
            c->ttsMin = 0;
        }
    } else if (type == DC_SAMPLE_GASMIX) {
        c->gas = (int) value->gasmix;
    }
}

// ---------------------------------------------------------------------------
// Callback por inmersión: parsea y añade al JSON
// ---------------------------------------------------------------------------

typedef struct {
    strbuf_t *sb; dc_device_t *device; int count; int maxDives;
} dive_ctx_t;

static int dive_cb(const unsigned char *data, unsigned int size,
                   const unsigned char *fp, unsigned int fsize, void *ud) {
    dive_ctx_t *dc = ud;
    dc_parser_t *parser = NULL;
    if (dc_parser_new(&parser, dc->device, data, size) != DC_STATUS_SUCCESS)
        return 1; // continuar con las demás

    if (dc->count++) sb_puts(dc->sb, ",");
    sb_puts(dc->sb, "{");

    // fingerprint (hex)
    sb_puts(dc->sb, "\"fingerprint\":\"");
    for (unsigned int i = 0; i < fsize; i++) sb_fmt(dc->sb, "%02x", fp[i]);
    sb_puts(dc->sb, "\"");

    dc_datetime_t dt;
    if (dc_parser_get_datetime(parser, &dt) == DC_STATUS_SUCCESS) {
        sb_fmt(dc->sb, ",\"datetime\":\"%04d-%02d-%02dT%02d:%02d:%02d\"",
               dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
    }
    unsigned int divetime = 0;
    if (dc_parser_get_field(parser, DC_FIELD_DIVETIME, 0, &divetime) == DC_STATUS_SUCCESS)
        sb_fmt(dc->sb, ",\"divetime\":%u", divetime);
    double maxdepth = 0;
    if (dc_parser_get_field(parser, DC_FIELD_MAXDEPTH, 0, &maxdepth) == DC_STATUS_SUCCESS)
        sb_fmt(dc->sb, ",\"maxdepth\":%.2f", maxdepth);
    double avgdepth = 0;
    if (dc_parser_get_field(parser, DC_FIELD_AVGDEPTH, 0, &avgdepth) == DC_STATUS_SUCCESS)
        sb_fmt(dc->sb, ",\"avgdepth\":%.2f", avgdepth);
    double tmin = 0;
    if (dc_parser_get_field(parser, DC_FIELD_TEMPERATURE_MINIMUM, 0, &tmin) == DC_STATUS_SUCCESS)
        sb_fmt(dc->sb, ",\"tempmin\":%.1f", tmin);

    unsigned int ngas = 0;
    if (dc_parser_get_field(parser, DC_FIELD_GASMIX_COUNT, 0, &ngas) == DC_STATUS_SUCCESS && ngas > 0) {
        sb_puts(dc->sb, ",\"gasmixes\":[");
        for (unsigned int i = 0; i < ngas; i++) {
            dc_gasmix_t mix = {0};
            if (dc_parser_get_field(parser, DC_FIELD_GASMIX, i, &mix) == DC_STATUS_SUCCESS) {
                if (i) sb_puts(dc->sb, ",");
                sb_fmt(dc->sb, "{\"o2\":%.3f,\"he\":%.3f}", mix.oxygen, mix.helium);
            }
        }
        sb_puts(dc->sb, "]");
    }

    sb_puts(dc->sb, ",\"samples\":[");
    sample_ctx_t sc = { .sb = dc->sb, .first = 1, .gas = -1 };
    dc_parser_samples_foreach(parser, sample_cb, &sc);
    flush_sample(&sc);
    sb_puts(dc->sb, "]}");

    dc_parser_destroy(parser);
    // maxDives > 0: parar tras N (p.ej. 1 para "marcar como ya importado").
    if (dc->maxDives > 0 && dc->count >= dc->maxDives) return 0;
    return 1;
}

// ---------------------------------------------------------------------------
// Progreso: reenvía DC_EVENT_PROGRESS a DiveComputer.reportProgress(cur,max)
// ---------------------------------------------------------------------------

typedef struct { JNIEnv *env; jclass cls; jmethodID mid; } prog_ctx_t;

static void event_cb(dc_device_t *device, dc_event_type_t event,
                     const void *data, void *ud) {
    (void) device;
    if (event != DC_EVENT_PROGRESS) return;
    prog_ctx_t *pc = ud;
    if (!pc->mid) return;
    const dc_event_progress_t *p = data;
    (*pc->env)->CallStaticVoidMethod(pc->env, pc->cls, pc->mid,
                                     (jint) p->current, (jint) p->maximum);
}

// ---------------------------------------------------------------------------
// Descarga principal
// ---------------------------------------------------------------------------

static dc_descriptor_t *find_descriptor(const char *vendor, const char *product) {
    dc_iterator_t *it = NULL;
    if (dc_descriptor_iterator(&it) != DC_STATUS_SUCCESS) return NULL;
    dc_descriptor_t *desc = NULL, *found = NULL;
    while (dc_iterator_next(it, &desc) == DC_STATUS_SUCCESS) {
        const char *v = dc_descriptor_get_vendor(desc);
        const char *p = dc_descriptor_get_product(desc);
        if (v && p && strcasecmp(v, vendor) == 0 && strcasecmp(p, product) == 0) {
            found = desc; break;
        }
        dc_descriptor_free(desc);
    }
    dc_iterator_free(it);
    return found;
}

// Decodifica una cadena hex ("a1b2...") a bytes. Devuelve la longitud en bytes.
static unsigned int hex_decode(const char *hex, unsigned char *out, unsigned int max) {
    unsigned int n = 0;
    for (; hex[0] && hex[1] && n < max; hex += 2, n++) {
        unsigned int b;
        if (sscanf(hex, "%2x", &b) != 1) break;
        out[n] = (unsigned char) b;
    }
    return n;
}

JNIEXPORT jstring JNICALL
Java_org_drslump_pandive_DiveComputer_nativeDownload(
        JNIEnv *env, jobject thiz, jstring jvendor, jstring jproduct,
        jobject conn, jstring jfingerprint, jint maxDives) {
    (void) thiz;
    const char *vendor = (*env)->GetStringUTFChars(env, jvendor, NULL);
    const char *product = (*env)->GetStringUTFChars(env, jproduct, NULL);

    strbuf_t out; sb_init(&out);

    dc_descriptor_t *desc = find_descriptor(vendor, product);
    if (!desc) {
        sb_fmt(&out, "{\"error\":\"Modelo no soportado: %s %s\"}", vendor, product);
        goto done;
    }

    dc_context_t *ctx = NULL;
    if (dc_context_new(&ctx) != DC_STATUS_SUCCESS) {
        sb_puts(&out, "{\"error\":\"No se pudo crear el contexto\"}");
        dc_descriptor_free(desc); goto done;
    }

    jclass cls = (*env)->GetObjectClass(env, conn);
    ble_io_t io = {0};
    io.env = env; io.conn = conn; io.timeout = 3000;
    io.readM = (*env)->GetMethodID(env, cls, "bleRead", "(I)[B");
    io.writeM = (*env)->GetMethodID(env, cls, "bleWrite", "([B)Z");

    dc_custom_cbs_t cbs = {0};
    cbs.set_timeout = io_set_timeout;
    cbs.read = io_read;
    cbs.write = io_write;

    dc_iostream_t *iostream = NULL;
    if (dc_custom_open(&iostream, ctx, DC_TRANSPORT_BLE, &cbs, &io) != DC_STATUS_SUCCESS) {
        sb_puts(&out, "{\"error\":\"No se pudo abrir el stream BLE\"}");
        dc_context_free(ctx); dc_descriptor_free(desc); goto done;
    }

    dc_device_t *device = NULL;
    dc_status_t rc = dc_device_open(&device, ctx, desc, iostream);
    if (rc != DC_STATUS_SUCCESS) {
        sb_fmt(&out, "{\"error\":\"No se pudo abrir el dispositivo (%d)\"}", rc);
        dc_iostream_close(iostream); dc_context_free(ctx); dc_descriptor_free(desc); goto done;
    }

    // Fingerprint: solo descargar inmersiones más nuevas que esta.
    if (jfingerprint) {
        const char *fphex = (*env)->GetStringUTFChars(env, jfingerprint, NULL);
        if (fphex && fphex[0]) {
            unsigned char fp[64];
            unsigned int fplen = hex_decode(fphex, fp, sizeof(fp));
            if (fplen) dc_device_set_fingerprint(device, fp, fplen);
        }
        if (fphex) (*env)->ReleaseStringUTFChars(env, jfingerprint, fphex);
    }

    // Progreso: DC_EVENT_PROGRESS -> DiveComputer.reportProgress(cur, max)
    jclass dcCls = (*env)->FindClass(env, "org/drslump/pandive/DiveComputer");
    prog_ctx_t pc = { env, dcCls, NULL };
    if (dcCls) pc.mid = (*env)->GetStaticMethodID(env, dcCls, "reportProgress", "(II)V");
    if (pc.mid) dc_device_set_events(device, DC_EVENT_PROGRESS, event_cb, &pc);

    sb_puts(&out, "{\"dives\":[");
    dive_ctx_t dctx = { .sb = &out, .device = device, .count = 0,
                        .maxDives = maxDives };
    rc = dc_device_foreach(device, dive_cb, &dctx);
    sb_puts(&out, "]");
    if (rc != DC_STATUS_SUCCESS)
        sb_fmt(&out, ",\"error\":\"Descarga incompleta (%d)\"", rc);
    sb_fmt(&out, ",\"count\":%d}", dctx.count);
    LOG("Descargadas %d inmersiones (rc=%d)", dctx.count, rc);

    dc_device_close(device);
    dc_iostream_close(iostream);
    dc_context_free(ctx);
    dc_descriptor_free(desc);

done:
    (*env)->ReleaseStringUTFChars(env, jvendor, vendor);
    (*env)->ReleaseStringUTFChars(env, jproduct, product);
    jstring result = (*env)->NewStringUTF(env, out.p ? out.p : "{\"error\":\"sin memoria\"}");
    sb_free(&out);
    return result;
}
