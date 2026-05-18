-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**
