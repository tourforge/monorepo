import 'package:flutter/material.dart';
import 'package:tourforge_baseline/tourforge.dart';

import 'onboarding.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runTourForge(
    config: TourForgeConfig(
      appName: "FMU Tour",
      appDesc:
          '''FMU Campus Tour is a GPS-based tour guide app for Francis Marion University.''',
      baseUrl: "https://tourforge.github.io/config/fmu-campus-tour",
      baseUrlIsIndirect: true,
      lightThemeData: lightThemeData,
      darkThemeData: darkThemeData,
    ),
    onboarding: (context, finish) {
      return Onboarding(finish: finish);
    },
  );
}
