-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }

-keep class net.sqlcipher.** { *; }
-keep class net.zetetic.database.** { *; }

# Reflection / Gson users shipped by plugins
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature,*Annotation*,InnerClasses,EnclosingMethod
# Flutter deferred components are not used
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
