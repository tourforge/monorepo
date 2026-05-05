import 'package:flutter/foundation.dart';

/// A reactive state container tracking the user's progress through the tour.
///
/// This model stores the integer index of the currently triggered waypoint.
/// It acts as the bridge between the spatial geofencing engine (`NavigationController`)
/// and the UI/Audio systems. When the user enters a new POI's radius, this index
/// is updated, triggering narration playback and UI changes (e.g., highlighting
/// the active step in the drawer).
class CurrentWaypointModel extends ChangeNotifier {
  int? _index;

  int? get index => _index;
  set index(int? newValue) {
    _index = newValue;
    notifyListeners();
  }
}
