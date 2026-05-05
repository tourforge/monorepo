import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:tourforge_baseline/src/data.dart';

/// A utility for managing local storage by identifying and deleting unreferenced
/// offline assets.
///
/// ### Architecture: Mark-and-Sweep Algorithm
/// The `AssetGarbageCollector` implements a classic "mark-and-sweep" memory
/// management technique applied to the file system.
///
/// 1.  **Mark Phase:** It parses the root `tourforge.json` manifest to build a
///     hash set of every asset ID (cryptographic hash) currently required by
///     the active tours.
/// 2.  **Sweep Phase:** It iterates over all files in the local storage directory.
///     If a file's name (its ID) is not present in the "marked" set, it is
///     considered "garbage" (an orphaned asset from an old update or deleted tour)
///     and is physically deleted.
class AssetGarbageCollector {
  /// The root directory containing downloaded assets.
  static late final String base;

  /// A basic semaphore to prevent concurrent garbage collection runs,
  /// which could lead to race conditions (e.g., trying to delete the same file twice).
  static bool isRunning = false;

  /// Executes the mark-and-sweep garbage collection cycle.
  ///
  /// The [ignoredTours] parameter allows for targeted deletion. If a user
  /// explicitly requests to "Delete Tour X", we add Tour X's ID to the ignored
  /// list. During the mark phase, its assets are not added to the `usedAssets`
  /// set. During the sweep phase, those assets will be deleted *unless* they are
  /// also referenced by another tour that is NOT ignored (demonstrating the
  /// power of deduplicated content-addressable storage).
  static Future<void> run({Set<String>? ignoredTours}) async {
    // Semaphore check to ensure thread safety.
    if (isRunning) return;
    isRunning = true;

    if (kDebugMode) {
      print("Asset garbage collector running.");
    }

    try {
      // Parse the master index to begin the Mark phase.
      var index = Project.parse(
          jsonDecode(await File("$base/tourforge.json").readAsString()));

      // HashSet provides O(1) lookup time for the Sweep phase.
      var usedAssets = HashSet<String>();

      // The index itself must never be deleted.
      usedAssets.add("tourforge.json");

      // Mark Phase: Populate the set of required assets.
      for (var tourEntry in index.tours) {
        if (ignoredTours != null && ignoredTours.contains(tourEntry.id)) {
          continue;
        }

        usedAssets.addAll(tourEntry.allAssets.map((e) => e.id));
      }

      // Sweep Phase: Iterate over the physical file system.
      await for (var entry in Directory(base).list()) {
        if (!usedAssets.contains(p.basename(entry.path))) {
          if (kDebugMode) {
            print("Asset garbage collector is deleting a file: ${entry.path}");
          }
          try {
            await entry.delete();
          } catch (e, stack) {
            // I/O Operations are inherently flaky (e.g., file locked by OS).
            // We swallow individual deletion exceptions to ensure the rest of
            // the sweep phase completes successfully.
            if (kDebugMode) {
              print("Error while deleting suspected garbage: $e");
              print("Garbage collection error stack trace: $stack");
              print("Continuing...");
            }
          }
        }
      }
    } catch (e, stack) {
      // Catch-all for fatal errors (e.g., index is corrupted).
      if (kDebugMode) {
        print("Unexpected error while garbage collecting: $e");
        print("Garbage collection error stack trace: $stack");
      }
    } finally {
      // Release the semaphore.
      if (kDebugMode) {
        print("Asset garbage collector finished.");
      }
      isRunning = false;
    }
  }
}
