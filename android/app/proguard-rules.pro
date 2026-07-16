-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# --- ML Kit ---
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-dontwarn com.google.mlkit.**

# --- Google Play Services (document scanner) ---
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# --- Syncfusion PDF ---
-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**

# --- Play Core (deferred components warnings from Flutter) ---
-dontwarn com.google.android.play.core.**

# --- Keep native/JNI & annotations ---
-keepattributes *Annotation*
-keepclasseswithmembernames class * {
    native <methods>;
}
