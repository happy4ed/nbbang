# ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# ML Kit model loading via reflection
-keep @com.google.android.gms.common.annotation.KeepName class *
-keepnames @com.google.android.gms.common.annotation.KeepName class *
-keepclassmembers class * {
    @com.google.android.gms.common.annotation.KeepName <methods>;
}
-keepnames class * implements com.google.android.gms.common.internal.safeparcel.SafeParcelable
-keep class * extends com.google.android.gms.** { *; }
-keepclassmembers class com.google.android.gms.** { *; }

# Kotlin
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings { <fields>; }

# Protobuf
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# image_picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Flutter embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**
