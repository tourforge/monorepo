# TourForge Ecosystem Knowledge Base

## 1. Architectural History and Rationalization

### The Legacy Problem: Fragmented Multi-Repo Distribution
Prior to this refactor, the TourForge ecosystem was distributed across three independent Git repositories: `baseline`, `florence-navigator`, and `fmu-campus-tour`. This structure created several critical engineering bottlenecks:

1.  **Manual Native Dependency Management:** The mapping engine relied on manual integration of MapLibre/Mapbox binaries. Developers had to manually download, extract, and link frameworks in Xcode. This was brittle and resistant to automation or reproducible builds.
2.  **Configuration Drift:** Since each application maintained its own `build.gradle` and `Podfile`, technical debt accumulated unevenly. Updates to the engine's native requirements (e.g., bumping NDK versions or iOS deployment targets) required manual, redundant edits across every consumer repository.
3.  **Brittle Dependency Resolution:** Consumer apps linked to the engine via Git URL dependencies in `pubspec.yaml`. This prevented simultaneous debugging of the engine and the app, as changes to the engine had to be committed and pushed before they could be tested in a consumer context.

### The Evolution & "The Why"
*   **Origin:** The project began as **Florence Navigator**, a standalone Flutter application designed to guide users through Florence, Italy, with offline maps and audio narration.
*   **Abstraction:** To support multiple cities without code duplication, the core logic was extracted into `tourforge_baseline`. This "White Label" engine handles map rendering (MapLibre), GPS navigation, audio playback, and UI orchestration.
*   **The Transition:** The move to a monorepo was driven by the need to eliminate the "manual zip extraction" era of dependency management and ensure that `git clone` && `melos bootstrap` is all a developer needs to get started.

### The Solution: Melos 7 and Dart Pub Workspaces
The monorepo architecture was implemented to consolidate these concerns into a single, atomic workspace.

1.  **Native Workspace Resolution:** By adopting Dart 3.6 Pub Workspaces, we eliminated Git-based dependencies. The engine and applications now reside in the same physical workspace, allowing the Dart analyzer and compiler to resolve changes in real-time across the entire ecosystem.
2.  **Codified Build Specifications:** We extracted shared native logic into the root `scripts/` directory. By using `apply from` (Gradle) and `require_relative` (Ruby/CocoaPods), we established a single source of truth for build requirements.
3.  **Automated Integrity Auditing:** To prevent the recurrence of configuration drift, we implemented a custom audit sentinel. This script enforces that all production applications remain structurally identical to the reference implementation (`baseline-app`), ensuring that the ecosystem scales without accumulating divergent technical debt.

## 2. Structural Roles
- packages/baseline: A Flutter plugin providing MapLibre integration, GPS navigation, and audio playback.
- apps/baseline-app: The reference implementation. It serves as the formal specification for native build configurations.
- apps/*: Production implementations that ingest the baseline engine.

## 3. Technical Standards

### Dart 3.6 Pub Workspaces
- resolution: workspace is enabled across all packages.
- SDK constraints are set to Dart ^3.6.0 and Flutter >=3.27.0.
- Intra-workspace dependencies are resolved via the workspace catalog.

### Native Configuration
Shared logic is located in the root scripts/ directory.
- Android: common.gradle enforces compileSdkVersion 36 and ndkVersion 29.
- iOS: common_podfile.rb enforces IPHONEOS_DEPLOYMENT_TARGET 13.0.

## 4. Workspace Integrity Sentinel

The validation script (scripts/validate_workspace.dart) prevents configuration drift.
- Baseline Comparison: Validates that target apps match the baseline-app build specification.
- Exclusions: The audit ignores distribution-specific lines such as applicationId and namespace.
- Requirements: Warns if key.properties or tomtom.txt are missing from required locations.

## 5. Environment Management

Environment consistency is maintained via devenv.
- Global SDKs: Root devenv.nix provides Flutter and Melos.
- Darwin Support: darwin.devenv.nix provides cocoapods and xcodes for macOS hosts.
- ABI Filtering: Android builds are restricted to arm64-v8a on Darwin hosts to reduce resource consumption.

## 6. Automated Tooling (Melos 7 & devenv)
- melos bootstrap: Links the workspace and initializes native dependencies.
- melos run validate: Executes the Workspace Integrity Audit.
- devenv shell check-elf-alignment <app-name>: Audits a compiled APK for 16KB ELF alignment using the centralized scripts/check_elf_alignment.sh.
- melos run android-build:build-apk: Orchestrates parallel APK builds across all apps.

## 7. Known Issues & Maintenance Protocols

### Legacy Xcode Configuration ("Ancient Build")
*   **Issue:** Some application `ios/Runner.xcodeproj` files may carry legacy settings that conflict with modern Flutter standards.
*   **Remedy Protocol (Clean Slate):**
    1.  **Backup:** Copy `ios/Runner/Info.plist` and `ios/Podfile`. Note the `Bundle Identifier`.
    2.  **Delete:** Remove the `ios/` folder.
    3.  **Regenerate:** Run `flutter create . --platforms ios --org <original.org>`.
    4.  **Restore:** Merge permissions (Location, Microphone) from backup `Info.plist`. Run `flutter pub run flutter_launcher_icons`.
    5.  **Verify:** `pod install` and build.

### "Multiple Info.plist" Build Error
*   **Context:** Occurs when transitioning from manual to automated setup if zombie references to `Mapbox.framework` persist.
*   **Resolution:** Surgically remove all `PBXBuildFile` and `PBXFileReference` entries pointing to `Mapbox.framework` in the `project.pbxproj` file.

## 9. Core Engine Technical Deep-Dive

### 9.1 Spatial Engine & Geofencing
The `NavigationController` provides a stateless-tick-based geofencing system.
*   **Coordinate Math:** Distances are calculated using the **Haversine formula**, which accounts for Earth's curvature by calculating the great-circle distance between two points on a sphere.
    *   *Reference:* "Haversine formula", Wikipedia.
*   **Trigger Logic:** The system performs an O(n) linear search for waypoints within a user's proximity on every GPS tick. To minimize CPU cycles, **temporal suppression** is used: if the GPS coordinate hasn't changed since the last tick, the search is bypassed.
*   **Zoom Calculation:** Map zoom levels are dynamically computed using a logarithmic mapping of the tour's spatial extent (radius from center): `zoom = -log(radius) / ln2 + C`. This ensures the entire tour route is always perfectly framed on launch.

### 9.2 Narration Subsystem
Background audio is managed via a bridge to the native platform's media session.
*   **The 'audio_service' Bridge:** By extending `BaseAudioHandler`, the engine ensures that Dart execution remains active in a persistent background process (Android Service / iOS Audio Session). This prevents the OS from suspending the app during a tour.
*   **Hardware Decoders:** The engine uses `just_audio` to interface with native decoders (AVPlayer/ExoPlayer), ensuring low-latency, hardware-accelerated playback of tour narrations.
*   **System Integration:** Media metadata (MediaItem) is dynamically pushed to the OS, enabling Lock Screen and Control Center playback controls.

### 9.3 Mapping Infrastructure (MapLibre GL)
The engine utilizes native MapLibre GL via **Platform Views** (`AndroidView` and `UiKitView`).
*   **Style Orchestration:** Because native GL engines cannot directly access Flutter's compressed asset bundle, the engine implements an extraction pipeline:
    1.  Extracts PBF fonts, PNG sprites, and JSON styles to the device's temporary directory.
    2.  Dynamically rewrites the Style JSON to use `file://` URIs for local assets.
    3.  Injects `mbtiles://` URIs for offline vector tile support.
*   **Vector vs. Satellite:** Street mapping uses vector tiles for crisp labels at all zoom levels, while satellite view integrates TomTom imagery via tile template URLs.

### 9.4 Performance & Optimization Patterns
*   **Isolate Isolation:** Heavy CPU tasks, such as decoding and cropping waypoint thumbnails for the notification shade, are offloaded to a separate **Dart Isolate** via `compute()`. This prevents "jank" (dropped frames) by keeping the main UI thread focused on rendering.
*   **GeoJSON Data Pipeline:** Geographic data (paths, markers) is serialized to GeoJSON strings in Dart and passed to native code. This allows the native MapLibre engine to use its optimized `GeoJSONSource` for high-performance rendering of route polylines and POI markers.
