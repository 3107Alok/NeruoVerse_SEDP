# Flutter core
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# Play Core (used by Flutter's deferred components — not used in this app, so just suppress)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.**

# Firebase
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
-keep public class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Hive
-keep class ** extends com.google.flatbuffers.Table { *; }
-dontwarn com.github.chenupt.**

# Java 8+ / desugaring
-dontwarn java.lang.invoke.**
-dontwarn java.lang.annotation.**
