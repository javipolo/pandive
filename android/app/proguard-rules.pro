# Clases cuyos métodos llama el código nativo (C) por nombre vía JNI.
# R8 no debe renombrarlas ni eliminarlas, o el puente libdivecomputer peta con
# NoSuchMethodError (bleRead/bleWrite/native*).
-keep class org.drslump.pandive.DiveComputer { *; }
-keep class org.drslump.pandive.BleConnection { *; }

# Métodos nativos en general.
-keepclasseswithmembernames class * {
    native <methods>;
}
