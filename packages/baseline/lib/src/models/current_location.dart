import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// A reactive state container for the user's current GPS coordinate.
///
/// This class extends [ChangeNotifier] and is injected into the widget tree
/// via the `provider` package. When the GPS stream pushes a new coordinate,
/// this model is updated, triggering a reactive rebuild of all widgets that
/// depend on the user's location (e.g., the map marker and navigation logic).
class CurrentLocationModel extends ChangeNotifier {
  LatLng? _value;

  LatLng? get value => _value;
  set value(LatLng? newValue) {
    _value = newValue;
    notifyListeners();
  }
}
