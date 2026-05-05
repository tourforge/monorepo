import 'package:flutter/foundation.dart';

/// A reactive state container for the map's visual layer style.
///
/// Controls the toggle between the default offline vector street map and
/// the online satellite imagery layer (e.g., TomTom). Updating this model
/// triggers the native MapLibre engine to hot-swap its styling JSON.
class SatelliteEnabledModel extends ChangeNotifier {
  bool _value = false;

  bool get value => _value;
  set value(bool newValue) {
    _value = newValue;
    notifyListeners();
  }
}
