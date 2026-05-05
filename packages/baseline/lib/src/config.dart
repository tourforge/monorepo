import 'package:flutter/material.dart';

/// Global access to the active TourForge configuration.
TourForgeConfig get tourForgeConfig => _tourForgeConfig;

late TourForgeConfig _tourForgeConfig;

/// Initializes the global configuration. Called during application bootstrap.
void setTourForgeConfig(TourForgeConfig config) {
  _tourForgeConfig = config;
}

/// The declarative configuration object injected by the consumer application.
///
/// This implements the "White Label" architectural pattern. The core engine
/// (`baseline`) contains no city-specific data. Instead, the consumer app
/// (e.g., `florence-navigator`) injects its specific branding, theme, and API
/// endpoints via this configuration object on startup.
class TourForgeConfig {
  const TourForgeConfig({
    required this.appName,
    this.appDesc,
    required this.baseUrl,
    this.baseUrlIsIndirect = false,
    required this.lightThemeData,
    required this.darkThemeData,
  });

  /// The name of the application, as displayed to users.
  final String appName;

  /// A description for the application to be displayed on the About page.
  final String? appDesc;

  /// The base URL for downloading tours and tour assets.
  final String baseUrl;

  /// Whether [baseUrl] is actually a pointer to another URL.
  ///
  /// ### Technical Context: Indirect Resolution
  /// If `true`, the engine will first perform an HTTP GET request to [baseUrl].
  /// It expects a JSON response containing the *real* base URL. This is a
  /// crucial mechanism for avoiding hardcoded API endpoints in compiled binaries.
  /// It allows the backend infrastructure to migrate or scale without requiring
  /// an App Store update to point to the new asset server.
  final bool baseUrlIsIndirect;

  /// The light theme for the application.
  final ThemeData lightThemeData;

  /// The dark theme for the application.
  final ThemeData darkThemeData;
}
