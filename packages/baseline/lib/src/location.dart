import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// A stateful manager for the GPS permission lifecycle.
///
/// This function acts as a facade over the `geolocator` plugin, handling the
/// complex asynchronous state machine required by modern mobile OSes for
/// location access.
///
/// ### Permission Lifecycle
/// Mobile operating systems enforce strict privacy controls. This function
/// evaluates and responds to the following states:
/// 1.  **Service Disabled:** Hardware GPS is turned off globally by the user.
///     Action: Prompt user to enable OS-level location services.
/// 2.  **Denied:** The app does not have permission.
///     Action: Request permission. The OS will present a native dialog.
/// 3.  **Denied Forever:** The user previously selected "Don't ask again."
///     Action: The app cannot programmatically request permission. We must
///     prompt the user to manually open the OS App Settings page.
/// 4.  **Granted:** The app has "While in use" or "Always" permission.
///
/// Returns `true` if permissions are granted and services are enabled, `false` otherwise.
Future<bool> requestGpsPermissions(BuildContext context) async {
  // Check hardware status first.
  if (!await Geolocator.isLocationServiceEnabled()) {
    if (!context.mounted) return false;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Location services disabled"),
          content: const Text(
            "Location services are disabled. "
            "Please enable them in order to be guided along tours.",
          ),
          actions: [
            TextButton(
              child: const Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    return false;
  }

  // Check app-specific authorization.
  var permission = await Geolocator.requestPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      if (!context.mounted) return false;
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Location services denied"),
            content: const Text(
              "Location services permission was denied. "
              "Please allow access in order to be guided along tours.",
            ),
            actions: [
              TextButton(
                child: const Text('Ok'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );

      return false;
    }
  }

  // Handle the unrecoverable state where the OS blocks further native prompts.
  if (permission == LocationPermission.deniedForever) {
    if (!context.mounted) return false;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Location services denied forever"),
          content: const Text(
            "Location services permission was permanently denied. "
            "The app cannot request permission. "
            "Please edit your settings to reenable the location services. ",
          ),
          actions: [
            TextButton(
              child: const Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  return true;
}

/// Acquires a continuous stream of GPS coordinate updates.
///
/// This function implicitly verifies permissions via [requestGpsPermissions]
/// before attempting to subscribe to the hardware location stream.
///
/// Returns a [Stream] of [LatLng] objects if successful, or `null` if permission
/// is denied or services are unavailable.
Future<Stream<LatLng>?> getLocationStream(BuildContext context) async {
  if (!context.mounted) return null;

  if (await requestGpsPermissions(context)) {
    return Geolocator.getPositionStream()
        .map((pos) => LatLng(pos.latitude, pos.longitude));
  } else {
    return null;
  }
}
