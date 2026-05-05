import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

/// A utility for calculating distances between coordinates.
///
/// In this implementation, [_distance] uses the Haversine formula, which calculates
/// the great-circle distance between two points on a sphere given their longitudes
/// and latitudes. This is a critical approximation for Earth-surface navigation.
///
/// For more information on the Haversine formula:
/// See: "Haversine formula", Wikipedia. https://en.wikipedia.org/wiki/Haversine_formula
const _distance = Distance();

/// Represents a geographic "trigger zone" or geofence in the navigation system.
///
/// This class encapsulates the spatial data required to determine if a user
/// has arrived at a point of interest (POI).
class NavigationWaypoint {
  const NavigationWaypoint({
    required this.position,
    required this.triggerRadius,
  });

  /// The geographic coordinate (latitude and longitude) of the waypoint.
  final LatLng position;

  /// The radius (in meters) around the [position] that defines the trigger area.
  ///
  /// In a mobile context, this value must account for GPS horizontal accuracy
  /// (CEP - Circular Error Probable). A radius too small (e.g., < 10m) may
  /// never be triggered due to GPS signal noise or multipath interference in
  /// urban canyons.
  final double triggerRadius;
}

/// The core logic engine for tracking user progress along a tour route.
///
/// The [NavigationController] implements a stateless-tick-based geofencing
/// algorithm. It is responsible for mapping a raw GPS coordinate to a specific
/// [NavigationWaypoint] in the tour's sequence.
///
/// ### Computational Geometry & Optimization
/// The controller performs a linear search (O(n)) through the waypoint list on
/// every 'tick' (location update). For the small scale of a typical walking
/// tour (dozens of waypoints), this is computationally trivial for modern
/// mobile CPUs. If scaling to thousands of points, a spatial index such as an
/// R-Tree or Quadtree would be required to reduce the search complexity to O(log n).
class NavigationController {
  NavigationController({
    this.path = const <LatLng>[],
    required this.waypoints,
  });

  /// The polyline representing the recommended walking path.
  final List<LatLng> path;

  /// The ordered sequence of waypoints for the tour.
  final List<NavigationWaypoint> waypoints;

  /// The index of the waypoint triggered in the previous tick.
  int? _prevWaypoint;

  /// The location from the previous tick, used for delta-suppression.
  LatLng? _location;

  /// Processes a single location update and returns the index of the active waypoint.
  ///
  /// This method implements a "nearest-neighbor" resolution within a geofence:
  /// 1. **Delta Check:** If the location hasn't changed, it returns the cached state
  ///    to avoid redundant calculations.
  /// 2. **Filter:** It identifies all waypoints where the distance from [location]
  ///    to the waypoint's center is less than its [triggerRadius].
  /// 3. **Resolve:** If multiple waypoints overlap the user's position, it selects
  ///    the one with the smallest distance (closest center).
  ///
  /// Returns the index of the triggered waypoint, or `null` if the user is
  /// outside all trigger zones.
  Future<int?> tick(BuildContext context, LatLng? location) async {
    var prevLocation = _location;
    _location = location;

    // Can't do anything if we don't know the current location.
    // This typically occurs if GPS signal is lost or permissions are denied.
    if (location == null) return null;

    // Temporal suppression: if current location hasn't changed since the last tick,
    // return the cached waypoint. This saves O(n) distance calculations.
    if (location == prevLocation) return _prevWaypoint;

    // Compute distances and filter for waypoints containing the current coordinate.
    // This is essentially a point-in-circle test for every POI.
    var nearbyWaypoints = waypoints
        .asMap()
        .entries
        .map((e) => _WaypointWithIndexAndDistance(
              index: e.key,
              position: e.value.position,
              triggerRadius: e.value.triggerRadius,
              distance: _distance(location, e.value.position),
            ))
        .where((e) => e.distance < e.triggerRadius)
        .toList();

    if (nearbyWaypoints.isNotEmpty) {
      // Tie-breaking: if the user is inside multiple geofences, pick the closest one.
      return _prevWaypoint = nearbyWaypoints
          .reduce((a, b) => a.distance < b.distance ? a : b)
          .index;
    } else {
      return _prevWaypoint = null;
    }
  }
}

/// Internal helper to pair waypoint metadata with its calculated distance.
class _WaypointWithIndexAndDistance {
  const _WaypointWithIndexAndDistance({
    required this.index,
    required this.position,
    required this.triggerRadius,
    required this.distance,
  });

  final int index;
  final LatLng position;
  final double triggerRadius;
  final double distance;
}
