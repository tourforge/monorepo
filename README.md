# TourForge Monorepo

This repository contains the TourForge mapping engine and its associated consumer applications. It uses a monorepo structure to manage the relationship between the shared engine and multiple branded implementations.

## History and Problem Solving

The TourForge ecosystem was originally distributed across multiple independent repositories. This decentralized structure presented several technical challenges as the project scaled.

### The Problem
- **Manual Dependency Linking**: Native dependencies were integrated manually into each application's iOS and Android folders. This made the build process fragile and non-reproducible across different developer environments.
- **Configuration Drift**: Each application maintained independent build files. Over time, these files diverged, leading to situations where an engine update would work in one application but fail in another due to inconsistent NDK versions or iOS deployment targets.
- **Workflow Latency**: The engine was imported via Git URLs. This meant that any modification to the core mapping logic required a commit and push cycle before it could be verified within a consumer application.

### The Solution: Monorepo Consolidation
This monorepo was established to resolve these inefficiencies by consolidating the engine and all applications into a single atomic workspace.
- **Direct Workspace Resolution**: By using Dart 3.6 Pub Workspaces, applications resolve the engine package locally. This enables real-time cross-package debugging and eliminates Git-based dependency overhead.
- **Centralized Build Specifications**: Shared native logic was moved to a root directory. Applications now reference these shared specifications, ensuring that SDK versions and build hooks remain synchronized across the entire ecosystem.
- **Automated Validation**: A workspace-wide audit tool was introduced to detect configuration drift, ensuring that all production implementations remain compliant with the reference build specification.

## Architectural Structure

This monorepo is managed by Melos. This format allows for centralized management of dependencies and build configurations across multiple packages.

### Directory Layout
- packages/baseline: The core Flutter plugin containing the mapping and navigation engine.
- apps/baseline-app: The reference implementation used for debugging and as a structural template.
- apps/florence-navigator: A production tour application for Florence, SC.
- apps/fmu-campus-tour: A production tour application for Francis Marion University.
- scripts/: Shared build logic for Android (Gradle) and iOS (CocoaPods).

## Technical Implementation

### Dart Pub Workspaces
This workspace uses the Dart 3.6 Pub Workspaces feature. All member packages include the resolution: workspace field in their pubspec.yaml. This configuration allows packages within the workspace to resolve each other natively without requiring relative path overrides.

### Build Specifications
Native build settings are centralized in the scripts/ directory.
- scripts/common.gradle: Defines Android SDK versions, NDK versions, and ABI filtering for all applications.
- scripts/common_podfile.rb: Defines the iOS deployment target and post-install hooks for all applications.

### Development Environment
The environment is managed by devenv (Nix). This ensures that the Flutter SDK, Melos, Android toolchain, and CocoaPods are synchronized across all development machines.

## Workspace Integrity Audit

The workspace includes a validation script located at scripts/validate_workspace.dart. This script performs the following checks:
1. Configuration Drift: Compares the build.gradle and Podfile of consumer apps against the baseline-app to ensure structural parity.
2. Resource Verification: Checks for the presence of required assets such as tomtom.txt.
3. Distribution Audit: Verifies that production apps have a key.properties file for Android signing.

The audit is executed via the following command:
`dart scripts/validate_workspace.dart`
