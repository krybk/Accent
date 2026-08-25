# Flutter's engine is reached through JNI, so the shrinker cannot see those
# entry points and would strip them. Without these rules a minified release
# build compiles fine and then crashes on launch.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_secure_storage reaches the Android Keystore reflectively.
-keep class androidx.security.crypto.** { *; }

# Flutter's embedding references Play Core for deferred components — split
# installs delivered by the Play Store. We distribute APKs directly, so those
# classes are not on the classpath and R8 fails the build over references it
# cannot resolve. Silencing them is correct rather than a workaround: the code
# paths that use them are unreachable in a directly-installed build.
#
# Should the app ever ship through the Play Store with deferred components, this
# rule has to go and the Play Core dependency has to come in instead.
-dontwarn com.google.android.play.core.**
