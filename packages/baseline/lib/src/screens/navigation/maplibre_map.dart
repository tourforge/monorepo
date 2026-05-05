import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../math.dart';
import '../../data.dart';

/// An imperative controller for the native MapLibre map instance.
///
/// This controller leverages [MethodChannel] to send commands to the native
/// platform view.
class MapLibreMapController {
  late final _MapLibreMapState _state;

  /// Toggles between vector-styled street view and TomTom satellite imagery.
  bool get satelliteEnabled => _state._satelliteEnabled;
  set satelliteEnabled(bool value) {
    _state._satelliteEnabled = value;

    // We switch the style by providing a file URI to a locally-generated JSON style.
    _MapLibreMapState._channel.invokeMethod<void>("setStyle",
        _state._satelliteEnabled ? _state.satStylePath : _state.stylePath);
  }

  /// Sends a GeoJSON FeatureCollection to the native map to update the user's
  /// location indicator.
  ///
  /// Using GeoJSON as a data interchange format allows us to leverage the
  /// native MapLibre GeoJSONSource, which is highly optimized for frequent updates.
  void updateLocation(LatLng location) {
    _MapLibreMapState._channel.invokeMethod<void>(
      "updateLocation",
      jsonEncode({
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {
              "type": "Point",
              "coordinates": [location.longitude, location.latitude],
            },
          },
        ],
      }),
    );
  }

  /// Commands the native map to animate the camera to a new coordinate.
  void moveCamera(LatLng where) {
    _MapLibreMapState._channel.invokeMethod<void>(
      "moveCamera",
      {
        "lat": where.latitude,
        "lng": where.longitude,
        "duration": 1500, // Duration in milliseconds.
      },
    );
  }
}

/// A specialized widget that embeds a native MapLibre map using Platform Views.
///
/// ### Architecture: Platform Views
/// To achieve maximum performance and access to hardware-accelerated GL rendering,
/// we use [AndroidView] and [UiKitView]. This embeds a native view into the
/// Flutter widget tree.
///
/// **Performance Note:** Platform Views have overhead due to texture sharing or
/// view layering. For high-performance mapping, we minimize full-widget rebuilds
/// and communicate primarily via [MethodChannel].
class MapLibreMap extends StatefulWidget {
  const MapLibreMap({
    super.key,
    required this.tour,
    required this.controller,
    required this.onMoveUpdate,
    required this.onMoveBegin,
    required this.onMoveEnd,
    required this.onCameraUpdate,
    required this.onPointClick,
    required this.onPoiClick,
    required this.fakeGpsOverlay,
  });

  final TourModel tour;
  final MapLibreMapController controller;
  final void Function() onMoveUpdate;
  final void Function() onMoveBegin;
  final void Function() onMoveEnd;
  final void Function(LatLng center, double zoom) onCameraUpdate;
  final void Function(int index) onPointClick;
  final void Function(int index) onPoiClick;
  final Widget fakeGpsOverlay;

  @override
  State<MapLibreMap> createState() => _MapLibreMapState();
}

class _MapLibreMapState extends State<MapLibreMap> {
  /// The control channel for the MapLibre plugin.
  /// This must match the string defined in the native Java/Swift implementation.
  static const _channel = MethodChannel("tourforge.org/baseline/map");

  late final String stylePath;
  late final String satStylePath;
  late Future<String> buildStyle;
  late final LatLng center;
  late final double zoom;

  bool _satelliteEnabled = false;

  @override
  void initState() {
    super.initState();

    widget.controller._state = this;

    // Style generation is an asynchronous I/O-bound task.
    buildStyle = _createStyle();

    // Register a handler for messages sent from the native code to Dart.
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case "updateCameraPosition":
          double lat = call.arguments["lat"];
          double lng = call.arguments["lng"];
          double zoom = call.arguments["zoom"];
          widget.onCameraUpdate(LatLng(lat, lng), zoom);
          break;
        case "moveUpdate":
          widget.onMoveUpdate();
          break;
        case "moveBegin":
          widget.onMoveBegin();
          break;
        case "moveEnd":
          widget.onMoveEnd();
          break;
        case "pointClick":
          widget.onPointClick(call.arguments["index"] as int);
          break;
        case "poiClick":
          widget.onPoiClick(call.arguments["index"] as int);
          break;
      }

      return null;
    });

    center =
        averagePoint(widget.tour.route.map((w) => LatLng(w.lat, w.lng)));
    zoom = _calculateTourZoom(widget.tour);
  }

  /// Generates the MapLibre GL Style JSON files required for the session.
  ///
  /// ### Technical Depth: Style Orchestration
  /// MapLibre styles are complex JSON objects that define data sources,
  /// layer ordering, and visual styling (colors, widths, icons). Since our
  /// assets (fonts, icons, MBTiles) are stored in the Flutter asset bundle,
  /// they are not directly accessible via standard file paths to the native
  /// MapLibre engine.
  ///
  /// **The Solution:**
  /// 1. **Extract Assets:** We copy PBF fonts, PNG sprites, and MBTiles from
  ///    the Flutter app bundle to the device's temporary directory.
  /// 2. **Dynamic Injection:** We read the base style JSON and replace template
  ///    URLs with "file://" URIs pointing to these extracted files.
  /// 3. **Offline Tiles:** We inject "mbtiles://" URIs, which our native
  ///    implementation (via MapLibre Custom Source) uses to serve vector tiles
  ///    locally without a network connection.
  Future<String> _createStyle() async {
    try {
      final spritePath = p.join((await getTemporaryDirectory()).path, "sprite");
      final spriteSatPath =
          p.join((await getTemporaryDirectory()).path, "sprite-satellite");
      stylePath = p.join((await getTemporaryDirectory()).path, "style.json");
      satStylePath =
          p.join((await getTemporaryDirectory()).path, "style-satellite.json");
      final fontsBasePath =
          p.join((await getTemporaryDirectory()).path, "fonts");
      final notoRegularPath =
          p.join(fontsBasePath, "Noto Sans Regular", "0-255.pbf");
      final notoBoldPath = p.join(fontsBasePath, "Noto Sans Bold", "0-255.pbf");
      final notoItalicPath =
          p.join(fontsBasePath, "Noto Sans Italic", "0-255.pbf");

      if (!mounted) return satStylePath;
      var assetBundle = DefaultAssetBundle.of(context);

      // check if we have tiles for the whole app
      ByteData? bundledTiles;
      try {
        bundledTiles = await assetBundle.load("assets/tiles.mbtiles");
      } on Exception {
        // an exception here simply means there are no bundled tiles
        // bundledTiles is set to null by default so we can just continue onwards
      }

      String? bundledTilesPath;
      if (bundledTiles != null) {
        bundledTilesPath = p.join((await getTemporaryDirectory()).path, "tiles.mbtiles");
        await File(bundledTilesPath).writeAsBytes(bundledTiles.buffer.asUint8List());
      }

      var assetPrefix = "packages/tourforge_baseline";
      var styleText =
          await assetBundle.loadString('$assetPrefix/assets/style.json');
      var satStyleText = await assetBundle
          .loadString('$assetPrefix/assets/style-satellite.json');
      var tomtomKey = "";
      try {
        tomtomKey = (await assetBundle.loadString('assets/tomtom.txt')).trim();
      } catch (e) {
        if (kDebugMode) {
          print("Failed to load TomTom key. Proceeding with empty key.");
        }
      }
      var spritePng = await assetBundle.load('$assetPrefix/assets/sprite.png');
      var spriteJson =
          await assetBundle.loadString('$assetPrefix/assets/sprite.json');
      var sprite2xPng =
          await assetBundle.load('$assetPrefix/assets/sprite@2x.png');
      var sprite2xJson =
          await assetBundle.loadString('$assetPrefix/assets/sprite@2x.json');
      var spriteSatPng =
          await assetBundle.load('$assetPrefix/assets/sprite-satellite.png');
      var spriteSatJson = await assetBundle
          .loadString('$assetPrefix/assets/sprite-satellite.json');
      var spriteSat2xPng =
          await assetBundle.load('$assetPrefix/assets/sprite-satellite@2x.png');
      var spriteSat2xJson = await assetBundle
          .loadString('$assetPrefix/assets/sprite-satellite@2x.json');
      var notoRegular = await assetBundle
          .load('$assetPrefix/assets/fonts/Noto Sans Regular/0-255.pbf');
      var notoBold = await assetBundle
          .load('$assetPrefix/assets/fonts/Noto Sans Bold/0-255.pbf');
      var notoItalic = await assetBundle
          .load('$assetPrefix/assets/fonts/Noto Sans Italic/0-255.pbf');

      var style = jsonDecode(styleText);
      var satStyle = jsonDecode(satStyleText);

      // Inject local URIs into the style JSON.
      satStyle["glyphs"] =
          style["glyphs"] = "file://$fontsBasePath/{fontstack}/{range}.pbf";
      satStyle["sprite"] = "file://$spriteSatPath";
      style["sprite"] = "file://$spritePath";
      if (widget.tour.tiles != null) {
        satStyle["sources"]["openmaptiles"]["url"] = style["sources"]
            ["openmaptiles"]["url"] = "mbtiles://${widget.tour.tiles!.localPath}";
      } else if (bundledTilesPath != null) {
        satStyle["sources"]["openmaptiles"]["url"] = style["sources"]
            ["openmaptiles"]["url"] = "mbtiles://$bundledTilesPath";
      }
      satStyle["sources"]["satellite"]["tiles"][0] =
          "https://api.tomtom.com/map/1/tile/sat/main/{z}/{x}/{y}.jpg?key=$tomtomKey";

      styleText = jsonEncode(style);
      satStyleText = jsonEncode(satStyle);

      await File("$spritePath.png")
          .writeAsBytes(spritePng.buffer.asUint8List());
      await File("$spritePath.json").writeAsString(spriteJson);
      await File("$spritePath@2x.png")
          .writeAsBytes(sprite2xPng.buffer.asUint8List());
      await File("$spritePath@2x.json").writeAsString(sprite2xJson);
      await File("$spriteSatPath.png")
          .writeAsBytes(spriteSatPng.buffer.asUint8List());
      await File("$spriteSatPath.json").writeAsString(spriteSatJson);
      await File("$spriteSatPath@2x.png")
          .writeAsBytes(spriteSat2xPng.buffer.asUint8List());
      await File("$spriteSatPath@2x.json").writeAsString(spriteSat2xJson);
      await File(stylePath).writeAsString(styleText);
      await File(satStylePath).writeAsString(satStyleText);
      await Directory(p.dirname(notoRegularPath)).create(recursive: true);
      await File(notoRegularPath)
          .writeAsBytes(notoRegular.buffer.asUint8List());
      await Directory(p.dirname(notoBoldPath)).create(recursive: true);
      await File(notoBoldPath).writeAsBytes(notoBold.buffer.asUint8List());
      await Directory(p.dirname(notoItalicPath)).create(recursive: true);
      await File(notoItalicPath).writeAsBytes(notoItalic.buffer.asUint8List());
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }

    return stylePath;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: buildStyle,
      builder: (context, snapshot) {
        if (snapshot.hasData && !snapshot.hasError) {
          // This is used in the platform side to register the view.
          const String viewType = 'org.tourforge.baseline.MapLibrePlatformView';
          // Pass parameters to the platform side.
          final Map<String, dynamic> creationParams = <String, dynamic>{
            "stylePath": snapshot.data,
            "pathGeoJson": _pathToGeoJson(widget.tour.path),
            "pointsGeoJson": _waypointsToGeoJson(widget.tour.route),
            "poisGeoJson": _poisToGeoJson(widget.tour.pois),
            "center": {"lat": center.latitude, "lng": center.longitude},
            "zoom": zoom,
          };

          return Stack(
            fit: StackFit.passthrough,
            children: [
              if (Platform.isAndroid)
                AndroidView(
                  viewType: viewType,
                  layoutDirection: TextDirection.ltr,
                  creationParams: creationParams,
                  creationParamsCodec: const StandardMessageCodec(),
                ),
              if (Platform.isIOS)
                UiKitView(
                  viewType: viewType,
                  layoutDirection: TextDirection.ltr,
                  creationParams: creationParams,
                  creationParamsCodec: const StandardMessageCodec(),
                ),
              widget.fakeGpsOverlay,
            ],
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }
}

/// Converts a coordinate list into a GeoJSON LineString for native rendering.
String _pathToGeoJson(List<LatLng> path) {
  return jsonEncode({
    "type": "FeatureCollection",
    "features": [
      {
        "type": "Feature",
        "geometry": {
          "type": "LineString",
          "coordinates": [
            for (var point in path) [point.longitude, point.latitude],
          ]
        }
      }
    ]
  });
}

/// Converts waypoints into a GeoJSON FeatureCollection with numeric labels.
String _waypointsToGeoJson(List<WaypointModel> waypoints) {
  return jsonEncode({
    "type": "FeatureCollection",
    "features": [
      for (var waypoint in waypoints.asMap().entries)
        {
          "type": "Feature",
          "properties": {"number": "${waypoint.key + 1}"},
          "geometry": {
            "type": "Point",
            "coordinates": [waypoint.value.lng, waypoint.value.lat],
          },
        },
    ],
  });
}

/// Converts POIs into a GeoJSON FeatureCollection.
String _poisToGeoJson(List<PoiModel> pois) {
  return jsonEncode({
    "type": "FeatureCollection",
    "features": [
      for (var poi in pois.asMap().entries)
        {
          "type": "Feature",
          "properties": {"name": poi.value.name},
          "geometry": {
            "type": "Point",
            "coordinates": [poi.value.lng, poi.value.lat],
          },
        },
    ],
  });
}

/// Computes an optimal zoom level to fit all tour waypoints.
///
/// ### Mathematical Logic
/// We use a logarithmic mapping between the spatial extent (max distance from
/// center) and the MapLibre zoom level. The formula:
/// `zoom = -log(radius) / ln2 + C`
/// maps a radius in meters to a zoom level where 1 unit of zoom represents a
/// doubling/halving of visual scale.
double _calculateTourZoom(TourModel tour) {
  var distance = const Distance();
  var center = averagePoint(tour.route.map((w) => LatLng(w.lat, w.lng)));
  var minRadius = tour.route
      .map((w) => distance(LatLng(w.lat, w.lng), center))
      .reduce(max);
  // 25.25 is an empirical constant adjusted for typical mobile screen densities.
  return max(-log(minRadius) / ln2 + 25.25 - 1.5, 1);
}
