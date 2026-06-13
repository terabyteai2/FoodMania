# QuickBytes Terminal — RAM Diagnostics (Sunmi VS2)

Date: 2026-06-13 · Device: Sunmi **V2s** (`V3B0243121704`), Android 12 / API 31, **armeabi-v7a (32-bit)**
Build profiled: `flutter run --profile` (AOT, release-like memory), pid 20497, pkg `com.terabyteai.foodmania.posadmin`
Tooling: `tools/ram_diag.sh` → CSV samples in `/tmp/ram_profile.csv`

## Device facts
- **Total RAM: 878 MB** (≈857 MB usable) — low-RAM class device.
- Free hovers **~20 MB**; MemAvailable ~325 MB; **swap pinned at ~460–600 MB used** of 642 MB → device is under constant memory pressure and thrashing.
- Disk `/data`: 4.4 GB, **51% used** (2.1 GB free) — fine, not a constraint.

## App memory (profile mode, idle, stable over ~50s — no leak/growth)
TOTAL PSS ≈ **137 MB**. App Summary breakdown:
| Bucket | PSS | Note |
|---|---|---|
| **Code** | ~30 MB | `.apk` mmap 18 MB + `.so` 7 MB + `.jar`/`.art`. Driven by 41.5 MB APK. |
| **Graphics** | ~29 MB | GL mtrack 22 MB + EGL 7 MB. GPU textures / image cache. |
| Java (Dart) Heap | ~8 MB | healthy |
| Native Heap | ~5 MB | healthy |
| Swapped out (SwapPss) | ~44 MB | even the foreground app is partly swapped |

**Conclusion:** Dart/native heaps are small and healthy — there is no Dart memory leak. The footprint is **assets/code size + graphics**, and the real pain is **OS-level RAM starvation**, not our heap.

## System-level RAM hogs (not our app, but they cause the swap)
GMS persistent 39 MB + GMS 31 MB (~70 MB), systemui 52 MB, launcher 43 MB,
**com.sunmi.remotecontrol.pro 29 MB**, inputmethod 25 MB, **com.sunmi.ota 13 MB**, sunmi.remotemanager 12 MB, sunmi.baseservice 9 MB.
→ Vendor + Google services eat the majority of 878 MB. Our 137 MB app is the largest single *app* but a minority of total.

## Build finding (the "minisdk" build)
`POS_TERMINAL_BUILD=true` sets `minSdk=22`, but **Flutter 3.44 tooling refuses it**:
`:app:ProfileMinSdkCheck — minimum Android SDK (22) is lower than Flutter's minimum supported version of 23`.
`flutter run/assemble` cannot build the minSdk-22 flavor. minSdk only changes the *install floor*; it has **no effect on runtime RAM** (VS2 is API 31). Profiling was done on the standard build, which is equivalent on this device.

---

# Suggestions (highest leverage first)

### 1. Cut the decoded-image cache (quick win, ~10–20 MB graphics) — `lib/main.dart:14-16`
48 MB / 120 images is too generous for an 878 MB device. Drop to ~16 MB / 40 images:
```dart
PaintingBinding.instance.imageCache
  ..maximumSizeBytes = 16 << 20 // 16 MB (was 48)
  ..maximumSize = 40;           // was 120
```
Directly reduces the 22 MB GL-mtrack / graphics bucket and live decode pressure.

### 2. Trim bundled assets → smaller APK → smaller `.apk`/code mmap (~18 MB at runtime)
- `assets/menu copy.jpg` (524 KB) — **accidental duplicate of `menu.jpg`**, delete + remove from `pubspec.yaml`.
- `assets/receipt.png` (**1.9 MB**) — recompress/resize; a thermal-receipt asset rarely needs 1.9 MB.
- `assets/menu.jpg` (524 KB) + `assets/menu_placeholders` (1.7 MB) — verify all are still referenced; downscale placeholders.
- Result: smaller `base.apk` lowers `.apk mmap` (18 MB private-clean today) and install size.

### 3. Gate the diagnostic logging — `92` `[QB-*-DIAG]` print sites
Hot paths (`orders_screen.dart`, `sync_service.dart`, `local_database_service.dart`) log on **every** order/sync tick, concatenating full order lists into multi-KB strings. In profile/release these `print()` calls still run → transient allocations + GC churn + CPU. Wrap them in a `kDebugMode`/`const bool kQbDiag = false` guard so they compile out of profile/release.

### 4. Reconsider `android:largeHeap="true"` — `AndroidManifest.xml:24`
Our Dalvik/Dart heap is only ~8 MB, so largeHeap buys us nothing but raises our heap ceiling and worsens system-wide LMK pressure on a 878 MB device. Safe to remove (re-test under heavy order load first).

### 5. Reduce font weight count (minor APK, ~0.5–1 MB)
5 families, 14 declarations (`pubspec.yaml:61-98`). `Inter.ttf` (876 KB) and `JetBrainsMono.ttf` are each mapped to 3 weights pointing at the **same file** (faux weights). Keep only weights actually used; drop unused families to shrink the APK.

### 6. Device hygiene (ops, not code)
The constant swap is mostly GMS + Sunmi services. For a dedicated POS terminal, consider disabling/uninstalling non-essential packages where the Sunmi MDM allows: `com.sunmi.ota`, `com.sunmi.remotecontrol.pro`, extra GMS, alternate IME. Frees ~80–120 MB and relieves swap for the POS app.

## How to re-measure
```bash
# 1) run standard profile build (minSdk-22 flavor won't build on Flutter 3.44):
flutter run --profile -d V3B0243121704
# 2) sample memory while exercising the app:
tools/ram_diag.sh -s V3B0243121704 -i 3 -n 20 -o /tmp/ram_after.csv
# 3) detailed one-shot:
adb -s V3B0243121704 shell dumpsys meminfo com.terabyteai.foodmania.posadmin | sed -n '1,40p'
```
Compare TOTAL PSS and the Graphics/Code buckets before vs after.
