package org.drslump.pandive

/**
 * Puente a libdivecomputer vía el wrapper JNI nativo (libpandive_dc.so).
 * Fase 2, hito A: solo consultas de capacidad (nº y lista de modelos
 * soportados) para verificar el enlace nativo.
 */
object DiveComputer {
    init {
        System.loadLibrary("pandive_dc")
    }

    external fun nativeSupportedCount(): Int
    external fun nativeSupportedList(): String
}
