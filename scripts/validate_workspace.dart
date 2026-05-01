import 'dart:io';

void main() {
  print('TourForge Workspace Integrity Audit');
  print('====================================\n');
  bool hasErrors = false;

  final appsDir = Directory('apps');
  if (!appsDir.existsSync()) {
    print('Error: Directory "apps/" not found at workspace root.');
    exit(1);
  }

  final apps = appsDir
      .listSync()
      .whereType<Directory>()
      .map((d) => d.path.split(Platform.pathSeparator).last)
      .toList()
    ..sort();

  if (apps.isEmpty) {
    print('No applications identified in the "apps/" directory.');
    return;
  }

  // The reference implementation defines the required build specification
  const referenceApp = 'baseline-app';
  
  if (!apps.contains(referenceApp)) {
    print('Critical Error: Reference implementation "$referenceApp" is missing.');
    exit(1);
  }

  print('Reference Build Specification: $referenceApp\n');

  for (final app in apps) {
    print('Auditing package: $app');

    // 1. Resource Verification (TomTom API)
    final tomtomPath = 'apps/$app/assets/tomtom.txt';
    if (!File(tomtomPath).existsSync()) {
      print('  Warning: Missing expected resource at $tomtomPath');
      print('  Impact: Build will lack satellite imagery support.');
    }

    // 2. Security Configuration Verification (Signing Identity)
    // The reference implementation is excluded from production signing requirements.
    if (app != referenceApp) {
      final keyPropsPath = 'apps/$app/android/key.properties';
      if (!File(keyPropsPath).existsSync()) {
        print('  Warning: Missing signing configuration at $keyPropsPath');
        print('  Impact: Package cannot be signed for production distribution.');
      }
    }

    // 3. Build Specification Compliance (Configuration Drift)
    if (app != referenceApp) {
      if (!auditConfiguration(referenceApp, app, 'android/app/build.gradle')) hasErrors = true;
      if (!auditConfiguration(referenceApp, app, 'ios/Podfile')) hasErrors = true;
    }
    print('');
  }

  if (hasErrors) {
    print('Audit Result: FAILED');
    print('Configuration drift detected in one or more member packages.');
    exit(1);
  } else {
    print('Audit Result: PASSED');
    print('Workspace integrity verified.');
  }
}

bool auditConfiguration(String reference, String target, String filePath) {
  final refFile = File('apps/$reference/$filePath');
  final targetFile = File('apps/$target/$filePath');

  if (!refFile.existsSync() || !targetFile.existsSync()) return true;

  final refLines = refFile.readAsLinesSync().map((l) => l.trim()).toList();
  final targetLines = targetFile.readAsLinesSync().map((l) => l.trim()).toList();

  // Pattern exclusions for distribution-specific or non-functional lines
  final exclusionPatterns = [
    'namespace',
    'applicationId',
    'versionCode',
    'versionName',
    'signingConfig',
    'bundle_id',
    'PRODUCT_BUNDLE_IDENTIFIER',
    '//',
    '#',
  ];

  bool isValidDefinition(String line) {
    if (line.isEmpty) return false;
    for (var pattern in exclusionPatterns) {
      if (line.contains(pattern)) return false;
    }
    return true;
  }

  final refDefinitions = refLines.where(isValidDefinition).toSet();
  final targetDefinitions = targetLines.where(isValidDefinition).toSet();

  final missingDefinitions = refDefinitions.difference(targetDefinitions);
  final redundantDefinitions = targetDefinitions.difference(refDefinitions);

  if (missingDefinitions.isNotEmpty || redundantDefinitions.isNotEmpty) {
    print('  Configuration Drift detected in $target/$filePath:');
    for (var line in missingDefinitions) {
      print('    [-] Missing expected definition: "$line"');
    }
    for (var line in redundantDefinitions) {
      print('    [+] Unexpected local definition: "$line"');
    }
    return false;
  }

  return true;
}
