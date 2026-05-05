import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'data.dart';

/// Exception thrown when a network request fails during an asset download.
class DownloadFailedException implements Exception {
  DownloadFailedException(this.response);

  /// The HTTP response that caused the failure, if available.
  final HttpClientResponse? response;
}

/// A robust asset synchronization engine responsible for local caching and
/// remote asset retrieval.
///
/// ### Resiliency & Fault Tolerance
/// The [DownloadManager] implements several enterprise-grade patterns:
///
/// 1. **Atomic File Operations:** Files are downloaded with a `.part` extension.
///    Only upon successful completion (verified by the HTTP stream closing
///    without error) is the file renamed to its final target. This prevents
///    "poisoning" the local cache with partial or corrupted assets.
/// 2. **Exponential Backoff with Jitter:** When a request fails, the manager
///    waits for a duration that doubles with each attempt. A "jitter" coefficient
///    (randomness) is added to prevent the "Thundering Herd" problem, where
///    many clients retry simultaneously and overwhelm the server.
/// 3. **Deduplication:** A request for an asset that is already being downloaded
///    will return the existing [Download] future/stream rather than initiating
///    a redundant connection.
class DownloadManager {
  DownloadManager(this.localBaseFut, this.networkBaseFut) {
    localBaseFut.then((value) => localBase = value);
    networkBaseFut.then((value) => networkBase = value);
  }

  static late final DownloadManager instance;

  /// The local directory path where assets are stored.
  final Future<String> localBaseFut;

  /// The remote base URL for asset retrieval.
  final Future<String> networkBaseFut;

  /// Tracks active downloads to enable deduplication.
  final Map<String, Download> _currentDownloads = {};

  final Set<String> _downloadedAssetNames = {};

  late final String localBase;
  late final String networkBase;

  /// Returns the current in-progress download of the given path, if any.
  Download? downloadInProgress(String path) => _currentDownloads[path];

  /// Checks if the given file is already downloaded.
  Future<bool> isDownloaded(String path) => File("$localBase/$path").exists();

  /// A cached version of [isDownloaded]. Might return false when the given path
  /// is actually downloaded.
  bool cachedIsDownloaded(String path) => _downloadedAssetNames.contains(path);

  /// Orchestrates the parallel download of multiple assets.
  ///
  /// This returns a [MultiDownload] which aggregates the progress of all
  /// underlying download streams.
  MultiDownload downloadAll(Iterable<AssetModel> assets,
      [Sink<DownloadProgress>? downloadProgress]) {
    var downloads = <Download>[];
    for (final asset in HashSet<AssetModel>.from(assets)) {
      downloads.add(download(asset));
    }

    return MultiDownload.of(downloads);
  }

  /// Initiates a download for a specific asset with retry logic.
  ///
  /// ### Technical Details: Exponential Backoff
  /// The wait time `retryIn` is calculated as:
  /// `(random_jitter + 0.5) * base_delay * 2^attempt`
  ///
  /// This ensures that retries are spread out over time, increasing the
  /// probability of recovery from transient network issues.
  Download download(AssetModel asset,
      {bool reDownload = false, int? maxRetries}) {
    var name = asset.id;

    var currentDownload = _currentDownloads[name];
    if (currentDownload != null) return currentDownload;

    final downloadProgress = StreamController<DownloadProgress>.broadcast();

    return _currentDownloads[name] = Download(
      downloadProgress: downloadProgress.stream,
      file: (() async {
        await Future.wait([localBaseFut, networkBaseFut]);

        var srcUri = Uri.parse("$networkBase/$name");
        var outDir = p.dirname("$localBase/$name");
        var outPath = "$localBase/$name";
        var partPath = "$localBase/$name.part";

        // don't redownload if it's unnecessary
        if (!reDownload && await File(outPath).exists()) {
          _markDownloaded(name);

          await downloadProgress.close();
          return File(outPath);
        }

        // create the directory where our files will go in case it doesn't exist
        await Directory(outDir).create(recursive: true);

        final rng = Random();
        var retryIn = 0;
        for (var i = 0; maxRetries != null ? i < maxRetries : true; i++) {
          if (retryIn > 0) {
            await Future.delayed(Duration(milliseconds: retryIn));
          }

          try {
            // attempt the download
            await _attemptDownload(srcUri, File(partPath), downloadProgress);

            // successfully downloaded!
            await downloadProgress.close();
            // Atomic swap: move the .part file to the final destination.
            await File(partPath).rename(outPath);

            _markDownloaded(name);

            return File(outPath);
          } on Exception catch (e) {
            if (e is DownloadFailedException) {
              if (asset.required) {
                rethrow;
              } else {
                return File(outPath);
              }
            }

            // exponential backoff: wait 0ms, then 500ms, then 1000ms, then 2000ms...
            // also multiply by random coefficient to prevent making lots of requests
            // at the same time when lots of requests fail at the same time
            retryIn = ((rng.nextDouble() + 0.5) * 500 * pow(2, i)).toInt();
            _printDebug(
                "Download of $name failed. Retrying in ${retryIn}ms... Context: $e");
          }
        }

        throw DownloadFailedException(null);
      })(),
    );
  }

  /// Low-level HTTP stream handling.
  ///
  /// This method pipes the [HttpClientResponse] stream directly into a
  /// [File.openWrite] sink while emitting progress updates. Direct streaming
  /// is memory-efficient as it avoids loading the entire asset into RAM.
  Future<void> _attemptDownload(
      Uri srcUri, File outFile, Sink<DownloadProgress> progress) async {
    var client = HttpClient();
    var req = await client.getUrl(srcUri);
    var resp = await req.close();

    if (resp.statusCode != 200) {
      throw DownloadFailedException(resp);
    }

    var totalDownloadSize =
        resp.contentLength != -1 ? resp.contentLength : null;

    var downloadedSize = 0;
    var outSink = outFile.openWrite();
    try {
      await outSink.addStream(resp.map((chunk) {
        downloadedSize += chunk.length;
        progress.add(DownloadProgress(
          totalDownloadSize: totalDownloadSize,
          downloadedSize: downloadedSize,
        ));
        return chunk;
      }));
    } on IOException {
      try {
        await outFile.delete();
      } catch (_) {}

      rethrow;
    } finally {
      try {
        await outSink.flush();
        await outSink.close();
      } catch (_) {}
    }

    progress.add(DownloadProgress(
      totalDownloadSize: downloadedSize,
      downloadedSize: downloadedSize,
    ));
  }

  Future<void> delete(AssetModel asset) async {
    await asset.downloadedFile.delete();
    _downloadedAssetNames.remove(asset.id);
  }

  void _printDebug(String message) {
    if (kDebugMode) print(message);
  }

  void _markDownloaded(String path) {
    _downloadedAssetNames.add(path);
  }
}

/// Represents a single active download task.
class Download {
  const Download({
    required this.downloadProgress,
    required this.file,
  });

  /// A stream that is updated with download progress as the file is downloaded.
  final Stream<DownloadProgress> downloadProgress;

  /// An object pointing to the downloaded file.
  final Future<File> file;
}

/// Aggregates multiple [Download] tasks into a single progress tracker.
class MultiDownload {
  MultiDownload({
    required this.downloadProgress,
    required this.completed,
  });

  /// Creates a [MultiDownload] from a list of active downloads.
  ///
  /// This factory listens to all sub-streams and calculates the total
  /// downloaded bytes vs total expected bytes across the entire set.
  factory MultiDownload.of(List<Download> downloads) {
    var controller = StreamController<DownloadProgress>.broadcast();

    var progresses = <DownloadProgress>[];
    for (final download in downloads) {
      final index = progresses.length;

      progresses.add(const DownloadProgress(downloadedSize: 0));
      download.downloadProgress.listen((progress) {
        progresses[index] = progress;

        controller.add(DownloadProgress.all(progresses));
      });
    }

    return MultiDownload(
      downloadProgress: controller.stream,
      completed: Future.wait(downloads.map((d) => d.file)),
    );
  }

  /// A stream that is updated with download progress as the files are downloaded.
  final Stream<DownloadProgress> downloadProgress;

  /// A future that completes when the download is completed.
  final Future<void> completed;
}

/// Data class representing the progress of one or more file downloads.
class DownloadProgress {
  const DownloadProgress({
    this.totalDownloadSize,
    required this.downloadedSize,
  });

  /// Total number of bytes that the remote file contains. May be null if unknown.
  final int? totalDownloadSize;

  /// Total number of bytes downloaded so far.
  final int downloadedSize;

  /// Aggregates a collection of progress updates into a single total.
  static DownloadProgress all(Iterable<DownloadProgress> progresses) =>
      progresses.reduce(
        (a, b) => DownloadProgress(
          totalDownloadSize:
              (a.totalDownloadSize ?? 0) + (b.totalDownloadSize ?? 0),
          downloadedSize: a.downloadedSize + b.downloadedSize,
        ),
      );
}
