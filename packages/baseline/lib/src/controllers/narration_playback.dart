import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../data.dart';

/// The possible operational states of the narration engine.
enum NarrationPlaybackState {
  playing,
  paused,
  completed,
  stopped,
  loading,
}

/// A high-level controller for managing audio narration, integrating background
/// playback and system-level media integration.
///
/// ### Architecture: The 'audio_service' Bridge
/// This class extends [BaseAudioHandler], which is the core of the `audio_service`
/// plugin. It acts as a bridge between the Flutter UI thread and the platform's
/// background audio task (Android Service or iOS Audio Session).
///
/// **Why is this necessary?** On mobile OSs, when an app moves to the background,
/// its Dart execution may be suspended. `audio_service` ensures that a persistent
/// background process remains active, allowing audio to continue playing and
/// enabling user control via the Lock Screen, Notification Shade, or wearable devices.
///
/// ### Technical Details: Media Interaction
/// - **just_audio:** Used for the actual playback logic. It leverages native
///   APIs (AVPlayer on iOS, ExoPlayer on Android) for efficient, hardware-accelerated
///   decoding.
/// - **MediaItem:** Metadata provided to the OS so it can display the current
///   waypoint title, tour name, and artwork in the system media controller.
class NarrationPlaybackController extends BaseAudioHandler with SeekHandler {
  static late final NarrationPlaybackController instance;

  /// Initializes the singleton instance of the controller and registers it with
  /// the system audio service.
  static Future<void> init() async {
    instance = await AudioService.init(
      builder: () => NarrationPlaybackController(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'org.tourforge.baseline.channel.audio',
        androidNotificationChannelName: 'Narration playback',
      ),
    );
  }

  NarrationPlaybackController() {
    // Reactive state synchronization:
    // We listen to the internal player's state and propagate it to both the
    // internal StreamController and the system's playbackState.
    _player.playerStateStream.listen((event) {
      _onStateChanged.add(null);
      _updatePlaybackState();
    });

    // Dynamic metadata updates:
    // When the duration is resolved (which may happen after loading starts),
    // we rebuild the MediaItem to include the correct duration for the seek bar.
    _player.durationStream.listen((duration) {
      if (_currentIndex == null || duration == null) return;

      buildMediaItem(tour.route[_currentIndex!], duration)
          .then(updateMediaItem);
    });

    _player.positionDiscontinuityStream.listen((event) {
      _updatePlaybackState();
    });
  }

  /// The model of the currently active tour.
  late TourModel tour;

  /// The underlying audio engine.
  AudioPlayer _player = AudioPlayer();

  final StreamController _onStateChanged = StreamController.broadcast();

  /// A stream that notifies listeners whenever the playback state changes.
  Stream<void> get onStateChanged => _onStateChanged.stream;

  /// Maps the complex [ProcessingState] of `just_audio` to a simplified [NarrationPlaybackState].
  NarrationPlaybackState get state {
    switch (_player.processingState) {
      case ProcessingState.idle:
        return NarrationPlaybackState.stopped;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return NarrationPlaybackState.loading;
      case ProcessingState.completed:
        return NarrationPlaybackState.completed;
      case ProcessingState.ready:
        return _player.playing
            ? NarrationPlaybackState.playing
            : NarrationPlaybackState.paused;
    }
  }

  int? _currentIndex;
  AssetModel? _currentNarration;

  /// A stream of the current playback position as a fraction (0.0 to 1.0).
  Stream<double> get onPositionChanged =>
      _player.positionStream.asyncMap<double>((duration) async =>
          (duration.inMilliseconds.toDouble()) /
          (_player.duration?.inMilliseconds.toDouble() ?? 0));

  /// Completely stops playback and resets the player state.
  Future<void> reset() async {
    await stop();
    _currentIndex = _currentNarration = null;
    mediaItem.add(null);
    await _player.dispose();
    _player = AudioPlayer();
  }

  /// Prepares and starts playback for a specific waypoint narration.
  ///
  /// This involves:
  /// 1. Building the [MediaItem] (including artwork processing).
  /// 2. Setting the native audio source (progressive file stream).
  /// 3. Initiating playback.
  Future<void> playWaypoint(int index) async {
    _currentIndex = index;
    _currentNarration = tour.route[index].narration;

    final mediaItem = await buildMediaItem(tour.route[index]);

    // Race condition check: If another waypoint was requested while we were
    // building the media item, abort this request.
    if (_currentIndex != index) return;

    this.mediaItem.add(mediaItem);
    if (_currentNarration == null) {
      _onStateChanged.add(null);
      _updatePlaybackState();
    } else {
      try {
        // We use ProgressiveAudioSource for local file playback to allow the
        // native engine to start playing before the entire file is cached in memory.
        await _player.setAudioSource(
            ProgressiveAudioSource(Uri.file(_currentNarration!.localPath)));
        await play();
      } on PlayerInterruptedException {
        // This call was interrupted by a subsequent playback request.
        // We catch this exception to allow the new request to proceed without crashing.
      } on PlayerException catch (e) {
        debugPrint("NarrationPlaybackController: Player error: ${e.message}");
      } catch (e) {
        debugPrint("NarrationPlaybackController: Unknown error: $e");
      }
    }
  }

  /// Constructs a [MediaItem] representing the current waypoint.
  ///
  /// ### Performance Optimization: Image Processing Isolation
  /// System media controllers (especially on iOS) require square artwork.
  /// If the waypoint image is not square, we must crop it. Decoding and
  /// manipulating large JPEGs is CPU-intensive and can cause "jank" (dropped frames)
  /// on the main UI thread.
  ///
  /// We solve this by using the [compute] function, which spawns a separate
  /// Dart Isolate. This moves the heavy JPEG decoding and cropping off the main
  /// thread, ensuring a smooth user interface.
  Future<MediaItem> buildMediaItem(WaypointModel waypoint,
      [Duration? duration]) async {
    Uri? artUri;
    if (waypoint.gallery.isNotEmpty) {
      var squarePath =
          "${(await getTemporaryDirectory()).path}/square-${waypoint.gallery.first.id}";
      artUri = Uri.file(squarePath);

      if (!await File(squarePath).exists()) {
        var imgContent =
            await File(waypoint.gallery.first.localPath).readAsBytes();

        // Perform image manipulation in a background Isolate.
        var square = await compute((imgContent) {
          var img = decodeImage(imgContent)!;

          // Crop and resize to 512x512 for high-density displays.
          return copyResizeCropSquare(img, size: 512);
        }, imgContent);

        await File(squarePath).writeAsBytes(encodeJpg(square));
      }
    }

    return MediaItem(
      id: waypoint.narration?.localPath ?? "${tour.title}/${waypoint.title}",
      title: waypoint.title,
      album: tour.title,
      artUri: artUri,
      duration: duration,
    );
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _onStateChanged.add(null);

    _updatePlaybackState();
  }

  @override
  Future<void> play() async {
    _player.play();
    _onStateChanged.add(null);
  }

  /// Seeks to a relative position in the audio track.
  Future<void> seekFractional(double position) async {
    var duration = Duration(
      milliseconds:
          ((_player.duration!.inMilliseconds.toDouble()) * position).toInt(),
    );

    await seek(duration);
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (_currentIndex == null || _currentIndex! >= tour.route.length - 1) {
      return;
    }

    playWaypoint(_currentIndex! + 1);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentIndex == null || _currentIndex! == 0) {
      return;
    }

    playWaypoint(_currentIndex! - 1);
  }

  /// Restarts the current narration from the beginning.
  Future<void> replay() async {
    var narration = _currentNarration;
    if (narration == null) return;

    await _player.stop();
    _player.seek(Duration.zero);
    _player.play();
    _onStateChanged.add(null);

    _updatePlaybackState();
  }

  /// Communicates the current playback state and available controls to the OS.
  ///
  /// This determines which buttons (Play/Pause/Next/Prev) appear on the
  /// lock screen and in the control center.
  void _updatePlaybackState() {
    playbackState.add(PlaybackState(
      controls: [
        if (_currentIndex != null) MediaControl.skipToPrevious,
        if (_currentIndex != null &&
            _player.processingState == ProcessingState.ready)
          _player.playing ? MediaControl.pause : MediaControl.play,
        if (_currentIndex != null) MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      processingState: AudioProcessingState.ready,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: 1.0,
      queueIndex: 0,
    ));
  }

  /// Utility to format the current position as a "MM:SS" string.
  String? positionToString(double position) {
    var fullDuration = _player.duration;
    if (fullDuration == null) return null;
    if (position.isNaN || !position.isFinite) return null;

    var duration = Duration(
      milliseconds: (fullDuration.inMilliseconds.toDouble() * position).toInt(),
    );

    var mins = "${duration.inMinutes}".padLeft(2, "0");
    var secs =
        "${duration.inSeconds - duration.inMinutes * 60}".padLeft(2, "0");

    return "$mins:$secs";
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
