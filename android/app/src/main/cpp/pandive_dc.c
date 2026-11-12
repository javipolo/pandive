// Puente JNI mínimo sobre libdivecomputer (Fase 2, hito A: verificar enlace).
// Expone el nº de ordenadores soportados y la lista "Vendor Product".
#include <jni.h>
#include <string.h>
#include <stdlib.h>

#include <libdivecomputer/descriptor.h>
#include <libdivecomputer/iterator.h>

// Cuenta los descriptores (modelos soportados) de libdivecomputer.
JNIEXPORT jint JNICALL
Java_org_drslump_pandive_DiveComputer_nativeSupportedCount(JNIEnv *env, jobject thiz) {
    (void) env; (void) thiz;
    dc_iterator_t *it = NULL;
    if (dc_descriptor_iterator(&it) != DC_STATUS_SUCCESS)
        return -1;
    jint n = 0;
    dc_descriptor_t *desc = NULL;
    while (dc_iterator_next(it, &desc) == DC_STATUS_SUCCESS) {
        n++;
        dc_descriptor_free(desc);
    }
    dc_iterator_free(it);
    return n;
}

// Lista "Vendor Product\n..." de todos los modelos soportados.
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
        const char *vendor = dc_descriptor_get_vendor(desc);
        const char *product = dc_descriptor_get_product(desc);
        if (!vendor) vendor = "";
        if (!product) product = "";
        size_t need = strlen(vendor) + strlen(product) + 3; // espacio + \n + \0
        if (len + need > cap) {
            cap *= 2;
            char *nb = realloc(buf, cap);
            if (!nb) { dc_descriptor_free(desc); break; }
            buf = nb;
        }
        len += snprintf(buf + len, cap - len, "%s %s\n", vendor, product);
        dc_descriptor_free(desc);
    }
    dc_iterator_free(it);

    jstring result = (*env)->NewStringUTF(env, buf);
    free(buf);
    return result;
}
