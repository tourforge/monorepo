import 'package:flutter/foundation.dart';

/// A reactive state container used exclusively for debugging and simulation.
///
/// When enabled, the app disconnects from the hardware GPS stream and allows
/// the developer to simulate movement by manually clicking on the map. This
/// is critical for testing geofencing logic without physically walking the route.
class FakeGpsModel extends ChangeNotifier {
  bool _value = false;

  bool get value => _value;
  set value(bool newValue) {
    _value = newValue;
    notifyListeners();
  }
}
