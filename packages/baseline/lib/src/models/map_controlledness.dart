import 'package:flutter/foundation.dart';

/// A reactive state container governing the map's auto-tracking camera behavior.
///
/// If `true`, the map camera is "locked" to the user's GPS coordinate and will
/// automatically pan as the user moves. If the user manually drags the map
/// (detected via UI gesture callbacks), this value is set to `false`, detaching
/// the camera from the GPS stream so the user can explore freely.
class MapControllednessModel extends ChangeNotifier {
  bool _value = false;

  bool get value => _value;
  set value(bool newValue) {
    _value = newValue;
    notifyListeners();
  }
}
