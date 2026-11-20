# Clases cuyos métodos llama el código nativo (C) por nombre vía JNI.
# R8 no debe renombrarlas ni eliminarlas, o el puente libdivecomputer peta con
# NoSuchMethodError (bleRead/bleWrite/native*).
-keep class org.drslump.pandive.DiveComputer { *; }
-keep class org.drslump.pandive.BleConnection { *; }

# Métodos nativos en general.
-keepclasseswithmembernames class * {
    native <methods>;
}

# flutter_local_notifications: persiste las notificaciones programadas con Gson
# usando TypeToken<List<...>>. R8/minify borra la firma genérica -> al programar
# en release lanza PlatformException "Missing type parameter" y NO se programa
# ninguna noti de caducidad. Mantener firma genérica + TypeToken + el plugin.
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class * extends com.google.gson.reflect.TypeToken
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
