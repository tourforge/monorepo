# TourForge Ecosystem Knowledge Base

## 1. Architectural History and Rationalization

### The Legacy Problem: Fragmented Multi-Repo Distribution
Prior to this refactor, the TourForge ecosystem was distributed across three independent Git repositories: `baseline`, `florence-navigator`, and `fmu-campus-tour`. This structure created several critical engineering bottlenecks:

1.  **Manual Native Dependency Management:** The mapping engine relied on manual integration of MapLibre/Mapbox binaries. Developers had to manually download, extract, and link frameworks in Xcode. This was brittle and resistant to automation or reproducible builds.
2.  **Configuration Drift:** Since each application maintained its own `build.gradle` and `Podfile`, technical debt accumulated unevenly. Updates to the engine's native requirements (e.g., bumping NDK versions or iOS deployment targets) required manual, redundant edits across every consumer repository.
3.  **Brittle Dependency Resolution:** Consumer apps linked to the engine via Git URL dependencies in `pubspec.yaml`. This prevented simultaneous debugging of the engine and the app, as changes to the engine had to be committed and pushed before they could be tested in a consumer context.

### The Solution: Melos 7 and Dart Pub Workspaces
The monorepo architecture was implemented to consolidate these concerns into a single, atomic workspace.

1.  **Native Workspace Resolution:** By adopting Dart 3.6 Pub Workspaces, we eliminated Git-based dependencies. The engine and applications now reside in the same physical workspace, allowing the Dart analyzer and compiler to resolve changes in real-time across the entire ecosystem.
2.  **Codified Build Specifications:** We extracted shared native logic into the root `scripts/` directory. By using `apply from` (Gradle) and `require_relative` (Ruby/CocoaPods), we established a single source of truth for build requirements.
3.  **Automated Integrity Auditing:** To prevent the recurrence of configuration drift, we implemented a custom audit sentinel. This script enforces that all production applications remain structurally identical to the reference implementation (`baseline-app`), ensuring that the ecosystem scales without accumulating divergent technical debt.

## 2. Structural Roles
- packages/baseline: A Flutter plugin providing MapLibre integration, GPS navigation, and audio playback.
- apps/baseline-app: The reference implementation. It serves as the formal specification for native build configurations.
- apps/*: Production implementations that ingest the baseline engine.

## 2. Technical Standards

### Dart 3.6 Pub Workspaces
- resolution: workspace is enabled across all packages.
- SDK constraints are set to Dart ^3.6.0 and Flutter >=3.27.0.
- Intra-workspace dependencies are resolved via the workspace catalog.

### Native Configuration
Shared logic is located in the root scripts/ directory.
- Android: common.gradle enforces compileSdkVersion 36 and ndkVersion 29.
- iOS: common_podfile.rb enforces IPHONEOS_DEPLOYMENT_TARGET 13.0.

## 3. Workspace Integrity Sentinel

The validation script (scripts/validate_workspace.dart) prevents configuration drift.
- Baseline Comparison: Validates that target apps match the baseline-app build specification.
- Exclusions: The audit ignores distribution-specific lines such as applicationId and namespace.
- Requirements: Warns if key.properties or tomtom.txt are missing from required locations.

## 4. Environment Management

Environment consistency is maintained via devenv.
- Global SDKs: Root devenv.nix provides Flutter and Melos.
- Darwin Support: darwin.devenv.nix provides cocoapods and xcodes for macOS hosts.
- ABI Filtering: Android builds are restricted to arm64-v8a on Darwin hosts to reduce resource consumption.

## 5. Automated Tooling (Melos 7 & devenv)
- melos bootstrap: Links the workspace and initializes native dependencies.
- melos run validate: Executes the Workspace Integrity Audit.
- devenv shell check-elf-alignment <app-name>: Audits a compiled APK for 16KB ELF alignment using the centralized scripts/check_elf_alignment.sh.
- melos run android-build:build-apk: Orchestrates parallel APK builds across all apps.

## 6. Maintenance Protocol
- Reference First: Structural changes must be applied to baseline-app and validated before being propagated to other apps.
- Script Usage: All native configuration changes should be moved into the root scripts/ directory when they apply to multiple applications.
- Continuous Validation: Run melos run validate to ensure no manual changes have introduced configuration drift.
