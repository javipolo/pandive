# Classes whose methods the native code (C) calls by name via JNI.
# R8 must not rename or remove them, or the libdivecomputer bridge breaks with
# NoSuchMethodError (bleRead/bleWrite/native*).
-keep class org.drslump.pandive.DiveComputer { *; }
-keep class org.drslump.pandive.BleConnection { *; }

# Native methods in general.
-keepclasseswithmembernames class * {
    native <methods>;
}

# flutter_local_notifications: persists scheduled notifications with Gson
# using TypeToken<List<...>>. R8/minify strips the generic signature -> scheduling
# in release throws PlatformException "Missing type parameter" and NO expiry
# notification gets scheduled. Keep generic signature + TypeToken + the plugin.
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class * extends com.google.gson.reflect.TypeToken
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
