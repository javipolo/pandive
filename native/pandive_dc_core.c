// Núcleo común sobre libdivecomputer (ver pandive_dc_core.h).
#include "pandive_dc_core.h"

#include <string.h>
#include <strings.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <unistd.h>

#include <libdivecomputer/common.h>
#include <libdivecomputer/context.h>
#include <libdivecomputer/descriptor.h>
#include <libdivecomputer/iterator.h>
#include <libdivecomputer/custom.h>
#include <libdivecomputer/iostream.h>
#include <libdivecomputer/device.h>
#include <libdivecomputer/parser.h>

#ifdef __ANDROID__
#include <android/log.h>
#define LOG(...) __android_log_print(ANDROID_LOG_INFO, "PandiveDC", __VA_ARGS__)
#else
#define LOG(...) do { fprintf(stderr, "PandiveDC: " __VA_ARGS__); fputc('\n', stderr); } while (0)
#endif

// Normaliza a minúsculas alfanuméricas (para comparar nombre/producto BLE).
static void normalize_alnum(const char *s, char *out, size_t cap) {
    size_t j = 0;
    for (size_t i = 0; s[i] && j + 1 < cap; i++) {
        unsigned char c = (unsigned char) s[i];
        if (c >= 'A' && c <= 'Z') c = (unsigned char) (c - 'A' + 'a');
        if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) out[j++] = (char) c;
    }
    out[j] = '\0';
}

// ---------------------------------------------------------------------------
// Buffer de texto dinámico (para construir el JSON)
// ---------------------------------------------------------------------------

typedef struct { char *p; size_t len, cap; } strbuf_t;

static void sb_init(strbuf_t *s) { s->cap = 4096; s->len = 0; s->p = malloc(s->cap); if (s->p) s->p[0] = '\0'; }
static void sb_ensure(strbuf_t *s, size_t extra) {
    if (s->len + extra + 1 <= s->cap) return;
    while (s->len + extra + 1 > s->cap) s->cap *= 2;
    char *np = realloc(s->p, s->cap);
    if (!np) { free(s->p); s->p = NULL; return; }
    s->p = np;
}
static void sb_puts(strbuf_t *s, const char *t) {
    if (!s->p) return;
    size_t n = strlen(t); sb_ensure(s, n);
    if (!s->p) return;
    memcpy(s->p + s->len, t, n); s->len += n; s->p[s->len] = '\0';
}
static void sb_fmt(strbuf_t *s, const char *fmt, ...) {
    if (!s->p) return;
    char tmp[256]; va_list ap; va_start(ap, fmt);
    vsnprintf(tmp, sizeof(tmp), fmt, ap); va_end(ap);
    sb_puts(s, tmp);
}

// ---------------------------------------------------------------------------
// Capacidad
// ---------------------------------------------------------------------------

int pdc_supported_count(void) {
    dc_iterator_t *it = NULL;
    if (dc_descriptor_iterator(&it) != DC_STATUS_SUCCESS) return -1;
    int n = 0;
    dc_descriptor_t *desc = NULL;
    while (dc_iterator_next(it, &desc) == DC_STATUS_SUCCESS) { n++; dc_descriptor_free(desc); }
    dc_iterator_free(it);
    return n;
}

char *pdc_supported_list(void) {
    strbuf_t sb; sb_init(&sb);
    dc_iterator_t *it = NULL;
    if (dc_descriptor_iterator(&it) == DC_STATUS_SUCCESS) {
        dc_descriptor_t *desc = NULL;
        while (dc_iterator_next(it, &desc) == DC_STATUS_SUCCESS) {
            const char *v = dc_descriptor_get_vendor(desc);
            const char *p = dc_descriptor_get_product(desc);
            sb_puts(&sb, v ? v : "");
            sb_puts(&sb, " ");
            sb_puts(&sb, p ? p : "");
            sb_puts(&sb, "\n");
            dc_descriptor_free(desc);
        }
        dc_iterator_free(it);
    }
    return sb.p ? sb.p : strdup("");
}

// Primer descriptor de libdivecomputer que reconoce el nombre BLE
// (dc_descriptor_filter). Así se soportan todos sus ordenadores sin lista propia.
char *pdc_match_name(const char *name) {
    char out[256];
    out[0] = '\0';
    char nname[160];
    normalize_alnum(name ? name : "", nname, sizeof(nname));
    int best = -1; // -1 nada, 0 match de marca, >0 longitud del prefijo de producto
    dc_iterator_t *it = NULL;
    if (name && dc_descriptor_iterator(&it) == DC_STATUS_SUCCESS) {
        dc_descriptor_t *desc = NULL;
        while (dc_iterator_next(it, &desc) == DC_STATUS_SUCCESS) {
            if (dc_descriptor_filter(desc, DC_TRANSPORT_BLE, name)) {
                const char *v = dc_descriptor_get_vendor(desc);
                const char *p = dc_descriptor_get_product(desc);
                // El filtro casa a nivel de marca; desambiguar por el nombre:
                // preferir el descriptor cuyo producto sea prefijo del nombre.
                char np[160];
                normalize_alnum(p ? p : "", np, sizeof(np));
                size_t nl = strlen(np);
                int score = (nl > 0 && strncmp(nname, np, nl) == 0) ? (int) nl : 0;
                if (score > best) {
                    best = score;
                    snprintf(out, sizeof(out), "%s\t%s", v ? v : "", p ? p : "");
                }
            }
            dc_descriptor_free(desc);
        }
        dc_iterator_free(it);
    }
    LOG("matchName '%s' -> '%s' (score %d)", name ? name : "", out, best);
    return strdup(out);
}

// ---------------------------------------------------------------------------
// I/O personalizado: delega en pdc_io_t (paquetes) con un búfer local.
// ---------------------------------------------------------------------------

typedef struct {
    pdc_io_t *io;
    int timeout;         // ms
    unsigned char buf[1024];
    size_t buflen, bufpos;
} ble_io_t;

static dc_status_t io_set_timeout(void *ud, int timeout) {
    ((ble_io_t *) ud)->timeout = timeout > 0 ? timeout : 3000;
    return DC_STATUS_SUCCESS;
}

static dc_status_t io_sleep(void *ud, unsigned int ms) {
    (void) ud;
    usleep(ms * 1000);
    return DC_STATUS_SUCCESS;
}

static dc_status_t io_configure(void *ud, unsigned int baudrate,
        unsigned int databits, dc_parity_t parity, dc_stopbits_t stopbits,
        dc_flowcontrol_t flowcontrol) {
    (void) ud; (void) baudrate; (void) databits; (void) parity;
    (void) stopbits; (void) flowcontrol;
    return DC_STATUS_SUCCESS; // no aplica a BLE; no-op para drivers que lo piden
}

static dc_status_t io_purge(void *ud, dc_direction_t direction) {
    (void) direction;
    ble_io_t *b = ud;
    b->buflen = b->bufpos = 0;
    return DC_STATUS_SUCCESS;
}

static dc_status_t io_read(void *ud, void *data, size_t size, size_t *actual) {
    ble_io_t *b = ud;
    if (b->bufpos >= b->buflen) {
        // sin datos en el búfer local: pedir un paquete al BLE
        int to = b->timeout > 0 ? b->timeout : 3000;
        int n = b->io->read_packet(b->io->ud, b->buf, sizeof(b->buf), to);
        if (n < 0) { *actual = 0; return DC_STATUS_IO; }
        if (n == 0) { *actual = 0; LOG("io_read timeout (%d ms)", to); return DC_STATUS_TIMEOUT; }
        b->buflen = (size_t) n; b->bufpos = 0;
    }
    size_t avail = b->buflen - b->bufpos;
    size_t copy = size < avail ? size : avail;
    memcpy(data, b->buf + b->bufpos, copy);
    b->bufpos += copy;
    *actual = copy;
    return DC_STATUS_SUCCESS;
}

static dc_status_t io_write(void *ud, const void *data, size_t size, size_t *actual) {
    ble_io_t *b = ud;
    int rc = b->io->write(b->io->ud, data, size);
    *actual = size;
    return rc == 0 ? DC_STATUS_SUCCESS : DC_STATUS_IO;
}

// ---------------------------------------------------------------------------
// Parseo de muestras del perfil
// ---------------------------------------------------------------------------

typedef struct {
    strbuf_t *sb;
    int first;
    int haveTime, haveDepth, haveTemp, haveDeco;
    int havePpo2, haveCns, havePres, haveRbt;
    unsigned int timeMs;
    double depth, temp, ceiling, ppo2, cns, pressure;
    int ndlMin, ttsMin, gas, rbt; // gas se arrastra; -1 = desconocido
} sample_ctx_t;

// Muestra: [t, depth, temp, ndl, tts, ceiling, gas, ppo2, cns, pressure, rbt]
static void _n(sample_ctx_t *c, int have, double v) {
    if (have) sb_fmt(c->sb, "%.2f,", v); else sb_puts(c->sb, "null,");
}

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
    if (c->gas >= 0) sb_fmt(c->sb, "%d,", c->gas); else sb_puts(c->sb, "null,");
    _n(c, c->havePpo2, c->ppo2);
    _n(c, c->haveCns, c->cns);
    _n(c, c->havePres, c->pressure);
    if (c->haveRbt) sb_fmt(c->sb, "%d]", c->rbt); else sb_puts(c->sb, "null]");
    c->haveDepth = c->haveTemp = c->haveDeco = 0;
    c->havePpo2 = c->haveCns = c->havePres = c->haveRbt = 0;
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
    } else if (type == DC_SAMPLE_PPO2) {
        c->ppo2 = value->ppo2.value; c->havePpo2 = 1;
    } else if (type == DC_SAMPLE_CNS) {
        c->cns = value->cns * 100.0; c->haveCns = 1; // fracción -> %
    } else if (type == DC_SAMPLE_PRESSURE) {
        c->pressure = value->pressure.value; c->havePres = 1;
    } else if (type == DC_SAMPLE_RBT) {
        c->rbt = (int) value->rbt; c->haveRbt = 1;
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
    strbuf_t *sb; dc_device_t *device; int count; int maxDives; pdc_io_t *io;
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
    // Progreso por buceo cuando hay límite (count/maxDives): el % por memoria
    // no sirve si solo bajamos N buceos.
    if (dc->maxDives > 0 && dc->io->progress)
        dc->io->progress(dc->io->ud, dc->count, dc->maxDives);
    // maxDives > 0: parar tras N (p.ej. 1 para "marcar como ya importado").
    if (dc->maxDives > 0 && dc->count >= dc->maxDives) return 0;
    return 1;
}

// Progreso: DC_EVENT_PROGRESS -> io->progress(cur, max)
static void event_cb(dc_device_t *device, dc_event_type_t event,
                     const void *data, void *ud) {
    (void) device;
    if (event != DC_EVENT_PROGRESS) return;
    pdc_io_t *io = ud;
    const dc_event_progress_t *p = data;
    io->progress(io->ud, (int) p->current, (int) p->maximum);
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

char *pdc_download(const char *vendor, const char *product,
                   const char *fingerprint_hex, int max_dives, pdc_io_t *io) {
    strbuf_t out; sb_init(&out);

    dc_descriptor_t *desc = find_descriptor(vendor, product);
    if (!desc) {
        sb_fmt(&out, "{\"error\":\"Unsupported model: %s %s\"}", vendor, product);
        goto done;
    }
    LOG("open %s %s model=0x%x", vendor, product, dc_descriptor_get_model(desc));

    dc_context_t *ctx = NULL;
    if (dc_context_new(&ctx) != DC_STATUS_SUCCESS) {
        sb_puts(&out, "{\"error\":\"Could not create the context\"}");
        dc_descriptor_free(desc); goto done;
    }

    ble_io_t bio = {0};
    bio.io = io; bio.timeout = 3000;

    dc_custom_cbs_t cbs = {0};
    cbs.set_timeout = io_set_timeout;
    cbs.configure = io_configure;
    cbs.purge = io_purge;
    cbs.sleep = io_sleep;
    cbs.read = io_read;
    cbs.write = io_write;

    dc_iostream_t *iostream = NULL;
    if (dc_custom_open(&iostream, ctx, DC_TRANSPORT_BLE, &cbs, &bio) != DC_STATUS_SUCCESS) {
        sb_puts(&out, "{\"error\":\"Could not open the BLE stream\"}");
        dc_context_free(ctx); dc_descriptor_free(desc); goto done;
    }

    dc_device_t *device = NULL;
    dc_status_t rc = dc_device_open(&device, ctx, desc, iostream);
    if (rc != DC_STATUS_SUCCESS) {
        sb_fmt(&out, "{\"error\":\"Could not open the device (%d)\"}", rc);
        dc_iostream_close(iostream); dc_context_free(ctx); dc_descriptor_free(desc); goto done;
    }

    // Fingerprint: solo descargar inmersiones más nuevas que esta.
    if (fingerprint_hex && fingerprint_hex[0]) {
        unsigned char fp[64];
        unsigned int fplen = hex_decode(fingerprint_hex, fp, sizeof(fp));
        if (fplen) dc_device_set_fingerprint(device, fp, fplen);
    }

    // Con límite, el progreso se emite por buceo (count/N) desde dive_cb; sin
    // límite usamos el progreso por memoria (DC_EVENT_PROGRESS).
    if (io->progress && max_dives == 0)
        dc_device_set_events(device, DC_EVENT_PROGRESS, event_cb, io);

    sb_puts(&out, "{\"dives\":[");
    dive_ctx_t dctx = { .sb = &out, .device = device, .count = 0,
                        .maxDives = max_dives, .io = io };
    rc = dc_device_foreach(device, dive_cb, &dctx);
    sb_puts(&out, "]");
    if (rc != DC_STATUS_SUCCESS)
        sb_fmt(&out, ",\"error\":\"Incomplete download (%d)\"", rc);
    sb_fmt(&out, ",\"count\":%d}", dctx.count);
    LOG("Descargadas %d inmersiones (rc=%d)", dctx.count, rc);

    dc_device_close(device);
    dc_iostream_close(iostream);
    dc_context_free(ctx);
    dc_descriptor_free(desc);

done:
    return out.p ? out.p : strdup("{\"error\":\"out of memory\"}");
}
