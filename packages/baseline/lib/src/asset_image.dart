import 'package:flutter/painting.dart';

import 'download_manager.dart';
import 'data.dart';

/// A custom Flutter [ImageProvider] that seamlessly integrates with the engine's
/// offline asset synchronization system.
///
/// ### Architecture
/// Standard Flutter network images (`NetworkImage`) cache data in RAM, which
/// is cleared when the app closes. This provider wraps a standard [FileImage]
/// but intercepts the resolution pipeline to ensure the asset is downloaded
/// to persistent local storage *before* attempting to read the file.
class AssetImage extends ImageProvider<FileImage> {
  AssetImage(this._asset, {this.scale = 1.0})
      : _fileImage = FileImage(_asset.downloadedFile, scale: scale);

  final AssetModel _asset;
  final double scale;
  final FileImage _fileImage;

  /// The entry point for the Flutter framework to resolve the image.
  ///
  /// This method checks the [DownloadManager]'s fast RAM cache to see if the
  /// asset is already present on disk. If not, it awaits the completion of a
  /// targeted download task before handing control back to the standard
  /// [FileImage] provider.
  @override
  Future<FileImage> obtainKey(ImageConfiguration configuration) {
    if (DownloadManager.instance.cachedIsDownloaded(_asset.id)) {
      return _fileImage.obtainKey(configuration);
    } else {
      return (() async {
        // Await the download completion. If it's already in progress,
        // DownloadManager handles deduplication automatically.
        await DownloadManager.instance.download(_asset).file;

        return _fileImage.obtainKey(configuration);
      })();
    }
  }

  @override
  // ignore: deprecated_member_use
  ImageStreamCompleter loadBuffer(FileImage key, DecoderBufferCallback decode) {
    return key.loadBuffer(key, decode);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is AssetImage &&
        other._asset.id == _asset.id &&
        other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(_asset.id, scale);
}
