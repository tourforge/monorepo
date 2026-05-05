import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Calculates the geographic center (centroid) of a collection of coordinates.
///
/// ### Geographic Math
/// Simply averaging latitude and longitude values produces incorrect results
/// because the Earth is spherical. For example, the average of longitude 179°
/// and -179° is mathematically 0°, but geographically they are practically adjacent
/// (near the antimeridian), so the true average should be 180°.
///
/// To solve this, we convert the spherical coordinates into 3D Cartesian vectors
/// (x, y, z), average the vectors, and then convert the resultant vector back
/// to spherical coordinates.
LatLng averagePoint(Iterable<LatLng> points) =>
    points.map((p) => p.toVec3()).reduce((a, b) => a + b).toLatLng();

/// A basic 3D Cartesian vector.
class Vec3 {
  Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  /// Converts this Cartesian vector back into a geographic coordinate.
  LatLng toLatLng() {
    var lat = atan(sqrt(x * x + y * y) / z);
    var lng = double.nan;
    if (x > 0) {
      lng = atan(y / x);
    } else if (x < 0 && y >= 0) {
      lng = atan(y / x) + pi;
    } else if (x < 0 && y < 0) {
      lng = atan(y / x) - pi;
    } else if (x == 0 && y > 0) {
      lng = pi / 2;
    } else if (x == 0 && y < 0) {
      lng = -pi / 2;
    }

    return LatLng(radianToDeg(lat), radianToDeg(lng));
  }

  double dot(Vec3 other) {
    return x * other.x + y * other.y + z * other.z;
  }

  Vec3 operator +(Vec3 other) {
    return Vec3(x + other.x, y + other.y, z + other.z);
  }
}

extension LatLngToVec3Extension on LatLng {
  /// Converts a geographic coordinate to a 3D Cartesian vector on a unit sphere.
  Vec3 toVec3() => Vec3(
        sin(degToRadian(latitude)) * cos(degToRadian(longitude)),
        sin(degToRadian(latitude)) * sin(degToRadian(longitude)),
        cos(degToRadian(latitude)),
      );
}
