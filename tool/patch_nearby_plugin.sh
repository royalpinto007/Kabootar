#!/usr/bin/env bash
#
# Make the app buildable with a modern Android toolchain.
#
# flutter_nearby_connections 1.1.2 (the mesh transport) was last published in
# 2021 and does not build against the toolchain `flutter create` generates today
# (AGP 9 / Gradle 9, Kotlin 2, Android 14+ foreground-service rules). Rather than
# fork the plugin, this script applies the minimum, well-understood fixes after
# `flutter pub get`, so the build is fully reproducible on any machine and in CI.
#
# Run after `flutter pub get`, from the repo root:
#   flutter pub get
#   bash tool/patch_nearby_plugin.sh
#   flutter build apk --debug
#
# Idempotent: safe to run repeatedly.
set -euo pipefail

echo "==> Pinning the app's Android Gradle Plugin / Gradle to versions that the"
echo "    2021-era plugin supports (the generated default is too new)."

SETTINGS="android/settings.gradle.kts"
WRAPPER="android/gradle/wrapper/gradle-wrapper.properties"
if [[ -f "$SETTINGS" ]]; then
  sed -i -E 's/id\("com\.android\.application"\) version "[0-9.]+"/id("com.android.application") version "8.11.1"/' "$SETTINGS"
fi
if [[ -f "$WRAPPER" ]]; then
  sed -i -E 's#gradle-[0-9.]+-all\.zip#gradle-8.14.3-all.zip#' "$WRAPPER"
fi

echo "==> Locating flutter_nearby_connections in the pub cache."
CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
PLUGIN="$(find "$CACHE" -type d -path '*flutter_nearby_connections-*/android' -not -path '*/example/*' 2>/dev/null | head -1 || true)"
if [[ -z "${PLUGIN:-}" ]]; then
  echo "!! flutter_nearby_connections not found in $CACHE. Run 'flutter pub get' first." >&2
  exit 1
fi
echo "    $PLUGIN"

echo "==> Modernising the plugin's android/build.gradle (namespace, drop jcenter"
echo "    and the stale AGP 3.5 buildscript, align JVM target to 17)."
cat > "$PLUGIN/build.gradle" <<'GRADLE'
group 'com.nankai.flutter_nearby_connections'
version '1.0-SNAPSHOT'

// AGP/Kotlin and repositories come from the root project (Flutter's plugin
// loader); AGP 8 requires an explicit `namespace`.
apply plugin: 'com.android.library'
apply plugin: 'kotlin-android'

android {
    namespace 'com.nankai.flutter_nearby_connections'
    compileSdkVersion 34

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
    lintOptions {
        disable 'InvalidPackage'
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = '17'
    }
}

dependencies {
    api 'com.google.android.gms:play-services-nearby:17.0.0'
    implementation 'com.google.code.gson:gson:2.10.1'
    implementation 'com.google.android.gms:play-services-location:17.1.0'
    implementation 'androidx.core:core-ktx:1.9.0'
    implementation "org.jetbrains.kotlin:kotlin-stdlib"
}
GRADLE

echo "==> Patching the plugin manifest: drop the 'package' attribute (AGP 8 uses"
echo "    namespace) and declare foregroundServiceType (Android 14+ requires it)."
MANIFEST="$PLUGIN/src/main/AndroidManifest.xml"
python3 - "$MANIFEST" <<'PY'
import sys
f = sys.argv[1]
s = open(f).read()
s = s.replace('\n    package="com.nankai.flutter_nearby_connections"', '')
s = s.replace(
    '''        <service
            android:name=".NearbyService"
            android:enabled="true"
            android:exported="false"/>''',
    '''        <service
            android:name=".NearbyService"
            android:enabled="true"
            android:exported="false"
            android:foregroundServiceType="connectedDevice"/>''',
)
open(f, 'w').write(s)
print("    manifest patched")
PY

echo "==> Removing the removed Flutter v1-embedding code (Registrar) from the"
echo "    plugin (deleted from modern Flutter)."
KT="$PLUGIN/src/main/kotlin/com/nankai/flutter_nearby_connections/FlutterNearbyConnectionsPlugin.kt"
python3 - "$KT" <<'PY'
import sys
f = sys.argv[1]
s = open(f).read()
s = s.replace("import io.flutter.plugin.common.PluginRegistry.Registrar\n", "")
old = '''    companion object {
        private const val viewTypeId = "flutter_nearby_connections"

        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), viewTypeId)
            channel.setMethodCallHandler(FlutterNearbyConnectionsPlugin())
        }
    }'''
new = '''    companion object {
        private const val viewTypeId = "flutter_nearby_connections"
    }'''
if old in s:
    s = s.replace(old, new)
open(f, 'w').write(s)
print("    v1 embedding removed")
PY

echo "==> Done. You can now run: flutter build apk --debug"
