// JNI bridge over the shared core (native/pandive_dc_core.c):
//  - nativeSupportedCount / nativeSupportedList / nativeMatchName.
//  - nativeDownload: BLE I/O is delegated to BleConnection (Kotlin) via JNI.
//    Everything happens on the calling thread, so the JNIEnv is always valid.
#include <jni.h>
#include <stdlib.h>
#include <string.h>

#include "pandive_dc_core.h"

static jstring take_string(JNIEnv *env, char *s) {
    jstring r = (*env)->NewStringUTF(env, s ? s : "");
    free(s);
    return r;
}

JNIEXPORT jint JNICALL
Java_org_drslump_pandive_DiveComputer_nativeSupportedCount(JNIEnv *env, jobject thiz) {
    (void) env; (void) thiz;
    return pdc_supported_count();
}

JNIEXPORT jstring JNICALL
Java_org_drslump_pandive_DiveComputer_nativeSupportedList(JNIEnv *env, jobject thiz) {
    (void) thiz;
    return take_string(env, pdc_supported_list());
}

JNIEXPORT jstring JNICALL
Java_org_drslump_pandive_DiveComputer_nativeMatchName(JNIEnv *env, jobject thiz,
                                                      jstring jname) {
    (void) thiz;
    const char *name = jname ? (*env)->GetStringUTFChars(env, jname, NULL) : NULL;
    char *r = pdc_match_name(name);
    if (name) (*env)->ReleaseStringUTFChars(env, jname, name);
    return take_string(env, r);
}

// ---------------------------------------------------------------------------
// I/O: BleConnection.bleRead(int): ByteArray? / bleWrite(ByteArray): Boolean
// ---------------------------------------------------------------------------

typedef struct {
    JNIEnv *env;
    jobject conn;
    jmethodID readM, writeM;
    jclass dcCls;
    jmethodID progM; // DiveComputer.reportProgress(int, int)
} jni_io_t;

static int jni_read(void *ud, unsigned char *buf, size_t cap, int timeout_ms) {
    jni_io_t *j = ud;
    JNIEnv *env = j->env;
    jbyteArray arr = (jbyteArray) (*env)->CallObjectMethod(env, j->conn, j->readM, timeout_ms);
    if (arr == NULL) return 0;
    jsize n = (*env)->GetArrayLength(env, arr);
    if (n > (jsize) cap) n = (jsize) cap;
    (*env)->GetByteArrayRegion(env, arr, 0, n, (jbyte *) buf);
    (*env)->DeleteLocalRef(env, arr);
    return (int) n;
}

static int jni_write(void *ud, const void *data, size_t size) {
    jni_io_t *j = ud;
    JNIEnv *env = j->env;
    jbyteArray arr = (*env)->NewByteArray(env, (jsize) size);
    (*env)->SetByteArrayRegion(env, arr, 0, (jsize) size, (const jbyte *) data);
    jboolean ok = (*env)->CallBooleanMethod(env, j->conn, j->writeM, arr);
    (*env)->DeleteLocalRef(env, arr);
    return ok ? 0 : -1;
}

static void jni_progress(void *ud, int cur, int max) {
    jni_io_t *j = ud;
    if (!j->progM) return;
    (*j->env)->CallStaticVoidMethod(j->env, j->dcCls, j->progM, (jint) cur, (jint) max);
}

JNIEXPORT jstring JNICALL
Java_org_drslump_pandive_DiveComputer_nativeDownload(
        JNIEnv *env, jobject thiz, jstring jvendor, jstring jproduct,
        jobject conn, jstring jfingerprint, jint maxDives) {
    (void) thiz;
    const char *vendor = (*env)->GetStringUTFChars(env, jvendor, NULL);
    const char *product = (*env)->GetStringUTFChars(env, jproduct, NULL);
    const char *fp = jfingerprint ? (*env)->GetStringUTFChars(env, jfingerprint, NULL) : NULL;

    jclass cls = (*env)->GetObjectClass(env, conn);
    jni_io_t j = {0};
    j.env = env;
    j.conn = conn;
    j.readM = (*env)->GetMethodID(env, cls, "bleRead", "(I)[B");
    j.writeM = (*env)->GetMethodID(env, cls, "bleWrite", "([B)Z");
    j.dcCls = (*env)->FindClass(env, "org/drslump/pandive/DiveComputer");
    if (j.dcCls) j.progM = (*env)->GetStaticMethodID(env, j.dcCls, "reportProgress", "(II)V");

    pdc_io_t io = { jni_read, jni_write, j.progM ? jni_progress : NULL, &j };
    char *json = pdc_download(vendor, product, fp ? fp : "", maxDives, &io);

    if (fp) (*env)->ReleaseStringUTFChars(env, jfingerprint, fp);
    (*env)->ReleaseStringUTFChars(env, jvendor, vendor);
    (*env)->ReleaseStringUTFChars(env, jproduct, product);
    return take_string(env, json);
}
