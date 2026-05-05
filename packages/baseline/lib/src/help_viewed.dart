import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A lightweight, file-system-based persistence mechanism for tracking which
/// onboarding screens the user has already seen.
///
/// ### Implementation Detail
/// Instead of using a database or Shared Preferences, this class simply
/// creates an empty (zero-byte) file named after the specific help screen's
/// `key`. The existence of the file is the boolean flag itself.
class HelpViewed {
  /// Returns `true` if the zero-byte file for this [key] exists.
  static Future<bool> viewed(String key) async {
    try {
      return await File(p.join((await getApplicationSupportDirectory()).path,
              "helpsviewed", key))
          .exists();
    } catch (e) {
      if (kDebugMode) {
        print("Caught exception while checking if help screen viewed: $e");
      }
      return false;
    }
  }

  /// Creates a zero-byte file for this [key] to mark the screen as viewed.
  static Future<void> markViewed(String key) async {
    try {
      await File(p.join((await getApplicationSupportDirectory()).path,
              "helpsviewed", key))
          .create(recursive: true);
    } catch (e) {
      if (kDebugMode) {
        print("Caught exception while marking help screen viewed: $e");
      }
    }
  }
}
