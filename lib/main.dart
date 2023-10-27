// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

part 'camera_image.dart';

final MethodChannel _channel = const MethodChannel('plugins.flutter.io/camera');

enum CameraLensDirection { front, back, external }

enum FlashMode {
  /// The flash is disabled
  off,

  /// Fire flash for this capture
  alwaysFlash,

  /// Flash light is continuously ON
  torch,

  /// Fire the flash for this capture if needed
  autoFlash,
}

/// Affect the quality of video recording and image capture:
///
/// If a preset is not available on the camera being used a preset of lower quality will be selected automatically.
enum ResolutionPreset {
  /// 352x288 on iOS, 240p (320x240) on Android
  low,

  /// 480p (640x480 on iOS, 720x480 on Android)
  medium,

  /// 720p (1280x720)
  high,

  /// 1080p (1920x1080)
  veryHigh,

  /// 2160p (3840x2160)
  ultraHigh,

  /// The highest resolution available.
  max,
}

// ignore: inference_failure_on_function_return_type
typedef onLatestImageAvailable = Function(CameraImage image);

/// Returns the resolution preset as a String.
String serializeResolutionPreset(ResolutionPreset resolutionPreset) {
  switch (resolutionPreset) {
    case ResolutionPreset.max:
      return 'max';
    case ResolutionPreset.ultraHigh:
      return 'ultraHigh';
    case ResolutionPreset.veryHigh:
      return 'veryHigh';
    case ResolutionPreset.high:
      return 'high';
    case ResolutionPreset.medium:
      return 'medium';
    case ResolutionPreset.low:
      return 'low';
  }
  throw ArgumentError('Unknown ResolutionPreset value');
}

CameraLensDirection _parseCameraLensDirection(String? string) {
  switch (string) {
    case 'front':
      return CameraLensDirection.front;
    case 'back':
      return CameraLensDirection.back;
    case 'external':
      return CameraLensDirection.external;
  }
  throw ArgumentError('Unknown CameraLensDirection value');
}

/// Completes with a list of available cameras.
///
/// May throw a [CameraException].
Future<List<CameraDescription>> availableCameras() async {
  try {
    final List<Map<dynamic, dynamic>> cameras = (await _channel
        .invokeListMethod<Map<dynamic, dynamic>>('availableCameras')) as List<Map<dynamic, dynamic>>;
    return cameras.map((Map<dynamic, dynamic> camera) {
      return CameraDescription(
        name: camera['name'],
        lensDirection: _parseCameraLensDirection(camera['lensFacing']),
        sensorOrientation: camera['sensorOrientation'],
      );
    }).toList();
  } on PlatformException catch (e) {
    throw CameraException(e.code, e.message);
  }
}

class CameraDescription {
  CameraDescription({this.name, this.lensDirection, this.sensorOrientation});

  final String? name;
  final CameraLensDirection? lensDirection;

  /// Clockwise angle through which the output image needs to be rotated to be upright on the device screen in its native orientation.
  ///
  /// **Range of valid values:**
  /// 0, 90, 180, 270
  ///
  /// On Android, also defines the direction of rolling shutter readout, which
  /// is from top to bottom in the sensor's coordinate system.
  final int? sensorOrientation;

  @override
  bool operator ==(Object o) {
    return o is CameraDescription &&
        o.name == name &&
        o.lensDirection == lensDirection;
  }

  @override
  int get hashCode {
    return hashValues(name, lensDirection);
  }

  @override
  String toString() {
    return '$runtimeType($name, $lensDirection, $sensorOrientation)';
  }
}

/// This is thrown when the plugin reports an error.
class CameraException implements Exception {
  CameraException(this.code, this.description);

  String code;
  String? description;

  @override
  String toString() => '$runtimeType($code, $description)';
}

// Build the UI texture view of the video data with textureId.
class CameraPreview extends StatelessWidget {
  const CameraPreview(this.controller);

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return controller.value.isInitialized!
        ? Texture(textureId: controller._textureId!)
        : Container();
  }
}

/// The state of a [CameraController].
class CameraValue {
  const CameraValue({
    this.isInitialized,
    this.errorDescription,
    this.previewSize,
    this.isRecordingVideo,
    this.isTakingPicture,
    this.isStreamingImages,
    this.autoFocusEnabled,
    this.flashMode,
    bool? isRecordingPaused,
  }) : _isRecordingPaused = isRecordingPaused;

  const CameraValue.uninitialized()
      : this(
      isInitialized: false,
      isRecordingVideo: false,
      isTakingPicture: false,
      isStreamingImages: false,
      isRecordingPaused: false,
      autoFocusEnabled: true,
      flashMode: FlashMode.off
  );

  /// True after [CameraController.initialize] has completed successfully.
  final bool? isInitialized;

  /// True when a picture capture request has been sent but as not yet returned.
  final bool? isTakingPicture;

  /// True when autofocus is on.
  final bool? autoFocusEnabled;

  /// FlashMode
  final FlashMode? flashMode;


  /// True when the camera is recording (not the same as previewing).
  final bool? isRecordingVideo;

  /// True when images from the camera are being streamed.
  final bool? isStreamingImages;

  final bool? _isRecordingPaused;

  /// True when camera [isRecordingVideo] and recording is paused.
  bool get isRecordingPaused => isRecordingVideo! && _isRecordingPaused!;

  final String? errorDescription;

  /// The size of the preview in pixels.
  ///
  /// Is `null` until  [isInitialized] is `true`.
  final Size? previewSize;

  /// Convenience getter for `previewSize.height / previewSize.width`.
  ///
  /// Can only be called when [initialize] is done.
  double get aspectRatio => previewSize!.height / previewSize!.width;

  bool get hasError => errorDescription != null;

  CameraValue copyWith({
    bool? isInitialized,
    bool? isRecordingVideo,
    bool? isTakingPicture,
    bool? isStreamingImages,
    String? errorDescription,
    Size? previewSize,
    bool? isRecordingPaused,
    bool? autoFocusEnabled,
    FlashMode? flashMode
  }) {
    return CameraValue(
      isInitialized: isInitialized ?? this.isInitialized,
      errorDescription: errorDescription,
      previewSize: previewSize ?? this.previewSize,
      isRecordingVideo: isRecordingVideo ?? this.isRecordingVideo,
      isTakingPicture: isTakingPicture ?? this.isTakingPicture,
      isStreamingImages: isStreamingImages ?? this.isStreamingImages,
      isRecordingPaused: isRecordingPaused ?? _isRecordingPaused,
      autoFocusEnabled: autoFocusEnabled ?? this.autoFocusEnabled,
      flashMode: flashMode ?? this.flashMode,
    );
  }

  @override
  String toString() {
    return '$runtimeType('
        'isRecordingVideo: $isRecordingVideo, '
        'isRecordingVideo: $isRecordingVideo, '
        'isInitialized: $isInitialized, '
        'errorDescription: $errorDescription, '
        'previewSize: $previewSize, '
        'isStreamingImages: $isStreamingImages)';
  }
}

/// Controls a device camera.
///
/// Use [availableCameras] to get a list of available cameras.
///
/// Before using a [CameraController] a call to [initialize] must complete.
///
/// To show the camera preview on the screen use a [CameraPreview] widget.
class CameraController extends ValueNotifier<CameraValue> {
  CameraController(this.description,
      this.resolutionPreset, {
        this.enableAudio = true,
        this.autoFocusEnabled = true,
        this.flashMode = FlashMode.off,
        this.enableAutoExposure = true
      }) : super(const CameraValue.uninitialized());

  final CameraDescription description;
  final ResolutionPreset resolutionPreset;

  /// Whether to include audio when recording a video.
  final bool enableAudio;

  ///Whether the auttoFocus is enabled
  final bool autoFocusEnabled;
  final FlashMode flashMode;
  final enableAutoExposure;

  int? _textureId;
  bool _isDisposed = false;
  StreamSubscription<dynamic>? _eventSubscription;
  StreamSubscription<dynamic>? _imageStreamSubscription;
  Completer<void>? _creatingCompleter;

  /// Initializes the camera on the device.
  ///
  /// Throws a [CameraException] if the initialization fails.
  Future<void> initialize() async {
    if (_isDisposed) {
      return Future<void>.value();
    }
    try {
      _creatingCompleter = Completer<void>();
      final Map<String, dynamic> reply =
      (await _channel.invokeMapMethod<String, dynamic>(
        'initialize',
        <String, dynamic>{
          'cameraName': description.name,
          'resolutionPreset': serializeResolutionPreset(resolutionPreset),
          'enableAudio': enableAudio,
          'autoFocusEnabled': autoFocusEnabled,
          'enableAutoExposure': enableAutoExposure,
          'flashMode': flashMode.index,
        },
      )) as Map<String, dynamic>;
      _textureId = reply['textureId'];
      value = value.copyWith(
        isInitialized: true,
        previewSize: Size(
          reply['previewWidth'].toDouble(),
          reply['previewHeight'].toDouble(),
        ),
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
    
    _eventSubscription =
        EventChannel('flutter.io/cameraPlugin/cameraEvents$_textureId')
            .receiveBroadcastStream()
            .listen(_listener);
    _creatingCompleter!.complete();
    return _creatingCompleter!.future;
  }

  /// Prepare the capture session for video recording.
  ///
  /// Use of this method is optional, but it may be called for performance
  /// reasons on iOS.
  ///
  /// Preparing audio can cause a minor delay in the CameraPreview view on iOS.
  /// If video recording is intended, calling this early eliminates this delay
  /// that would otherwise be experienced when video recording is started.
  /// This operation is a no-op on Android.
  ///
  /// Throws a [CameraException] if the prepare fails.
  Future<void> prepareForVideoRecording() async {
    await _channel.invokeMethod<void>('prepareForVideoRecording');
  }

  /// Listen to events from the native plugins.
  ///
  /// A "cameraClosing" event is sent when the camera is closed automatically by the system (for example when the app go to background). The plugin will try to reopen the camera automatically but any ongoing recording will end.
  void _listener(dynamic event) {
    final Map<dynamic, dynamic>? map = event;
    if (_isDisposed) {
      return;
    }

    switch (map!['eventType']) {
      case 'error':
        value = value.copyWith(errorDescription: event['errorDescription']);
        break;
      case 'cameraClosing':
        value = value.copyWith(isRecordingVideo: false);
        break;
    }
  }


  /// Captures an image and saves it to [path].
  ///
  /// A path can for example be obtained using
  /// [path_provider](https://pub.dartlang.org/packages/path_provider).
  ///
  /// If a file already exists at the provided path an error will be thrown.
  /// The file can be read as this function returns.
  ///
  /// Throws a [CameraException] if the capture fails.
  Future<void> takePicture(String path) async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController.',
        'takePicture was called on uninitialized CameraController',
      );
    }
    if (value.isTakingPicture!) {
      throw CameraException(
        'Previous capture has not returned yet.',
        'takePicture was called before the previous capture returned.',
      );
    }
    try {
      value = value.copyWith(isTakingPicture: true);
      await _channel.invokeMethod<void>(
        'takePicture',
        <String, dynamic>{'textureId': _textureId, 'path': path},
      );
      value = value.copyWith(isTakingPicture: false);
    } on PlatformException catch (e) {
      value = value.copyWith(isTakingPicture: false);
      throw CameraException(e.code, e.message);
    }
  }

  /// Start streaming images from platform camera.
  ///
  /// Settings for capturing images on iOS and Android is set to always use the
  /// latest image available from the camera and will drop all other images.
  ///
  /// When running continuously with [CameraPreview] widget, this function runs
  /// best with [ResolutionPreset.low]. Running on [ResolutionPreset.high] can
  /// have significant frame rate drops for [CameraPreview] on lower end
  /// devices.
  ///
  /// Throws a [CameraException] if image streaming or video recording has
  /// already started.
  // TODO(bmparr): Add settings for resolution and fps.
  Future<void> startImageStream(onLatestImageAvailable onAvailable) async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'startImageStream was called on uninitialized CameraController.',
      );
    }
    if (value.isRecordingVideo!) {
      throw CameraException(
        'A video recording is already started.',
        'startImageStream was called while a video is being recorded.',
      );
    }
    if (value.isStreamingImages!) {
      throw CameraException(
        'A camera has started streaming images.',
        'startImageStream was called while a camera was streaming images.',
      );
    }

    try {
      await _channel.invokeMethod<void>('startImageStream');
      value = value.copyWith(isStreamingImages: true);
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
    const EventChannel cameraEventChannel =
    EventChannel('plugins.flutter.io/camera/imageStream');
    _imageStreamSubscription =
        cameraEventChannel.receiveBroadcastStream().listen(
              (dynamic imageData) {
            onAvailable(CameraImage._fromPlatformData(imageData));
          },
        );
  }

  /// Stop streaming images from platform camera.
  ///
  /// Throws a [CameraException] if image streaming was not started or video
  /// recording was started.
  Future<void> stopImageStream() async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'stopImageStream was called on uninitialized CameraController.',
      );
    }
    if (value.isRecordingVideo!) {
      throw CameraException(
        'A video recording is already started.',
        'stopImageStream was called while a video is being recorded.',
      );
    }
    if (!value.isStreamingImages!) {
      throw CameraException(
        'No camera is streaming images',
        'stopImageStream was called when no camera is streaming images.',
      );
    }

    try {
      value = value.copyWith(isStreamingImages: false);
      await _channel.invokeMethod<void>('stopImageStream');
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }

    await _imageStreamSubscription!.cancel();
    _imageStreamSubscription = null;
  }

  /// Start a video recording and save the file to [path].
  ///
  /// A path can for example be obtained using
  /// [path_provider](https://pub.dartlang.org/packages/path_provider).
  ///
  /// The file is written on the flight as the video is being recorded.
  /// If a file already exists at the provided path an error will be thrown.
  /// The file can be read as soon as [stopVideoRecording] returns.
  ///
  /// Throws a [CameraException] if the capture fails.
  Future<void> startVideoRecording(String filePath) async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'startVideoRecording was called on uninitialized CameraController',
      );
    }
    if (value.isRecordingVideo!) {
      throw CameraException(
        'A video recording is already started.',
        'startVideoRecording was called when a recording is already started.',
      );
    }
    if (value.isStreamingImages!) {
      throw CameraException(
        'A camera has started streaming images.',
        'startVideoRecording was called while a camera was streaming images.',
      );
    }

    try {
      await _channel.invokeMethod<void>(
        'startVideoRecording',
        <String, dynamic>{'textureId': _textureId, 'filePath': filePath},
      );
      value = value.copyWith(isRecordingVideo: true, isRecordingPaused: false);
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Stop recording.
  Future<void> stopVideoRecording() async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'stopVideoRecording was called on uninitialized CameraController',
      );
    }
    if (!value.isRecordingVideo!) {
      throw CameraException(
        'No video is recording',
        'stopVideoRecording was called when no video is recording.',
      );
    }
    try {
      value = value.copyWith(isRecordingVideo: false);
      await _channel.invokeMethod<void>(
        'stopVideoRecording',
        <String, dynamic>{'textureId': _textureId},
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Pause video recording.
  ///
  /// This feature is only available on iOS and Android sdk 24+.
  Future<void> pauseVideoRecording() async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'pauseVideoRecording was called on uninitialized CameraController',
      );
    }
    if (!value.isRecordingVideo!) {
      throw CameraException(
        'No video is recording',
        'pauseVideoRecording was called when no video is recording.',
      );
    }
    try {
      value = value.copyWith(isRecordingPaused: true);
      await _channel.invokeMethod<void>(
        'pauseVideoRecording',
        <String, dynamic>{'textureId': _textureId},
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Resume video recording after pausing.
  ///
  /// This feature is only available on iOS and Android sdk 24+.
  Future<void> resumeVideoRecording() async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController',
        'resumeVideoRecording was called on uninitialized CameraController',
      );
    }
    if (!value.isRecordingVideo!) {
      throw CameraException(
        'No video is recording',
        'resumeVideoRecording was called when no video is recording.',
      );
    }
    try {
      value = value.copyWith(isRecordingPaused: false);
      await _channel.invokeMethod<void>(
        'resumeVideoRecording',
        <String, dynamic>{'textureId': _textureId},
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  // Set autoFocusEnabled on camera
  Future<void> setAutoFocus(bool newValue) async {
    value = value.copyWith(autoFocusEnabled: newValue);
    try {
      await _channel.invokeMethod<void>(
        'setAutoFocus',
        <String, dynamic>{'autoFocusValue': newValue},
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  // Set setFlashMode on camera
  Future<void> setFlashMode(FlashMode flashMode) async {
    value = value.copyWith(flashMode: flashMode);
    try {
      await _channel.invokeMethod<void>(
        'setFlashMode',
        <String, dynamic>{'flashMode': flashMode.index},
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  ///
  /// change zoom by specific [step].
  ///
  Future<void> zoom(double step) async {
    await _channel.invokeMethod<void>('zoom', <String, dynamic>{'step': step});
  }

  Future<Null> setPointOfInterest(Offset offset) async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController.',
        'takePicture was called on uninitialized CameraController',
      );
    }
    try {
      await _channel.invokeMethod(
        'setPointOfInterest',
        <String, dynamic>{'offsetX': offset.dx, 'offsetY': offset.dy},
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// check if the device has a flash.
  Future<bool?> get hasFlash async {
    if (!value.isInitialized! || _isDisposed) {
      throw CameraException(
        'Uninitialized CameraController.',
        'hasFlash was called on uninitialized CameraController',
      );
    }

    try {
      return await _channel.invokeMethod<bool>('hasFlash');
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Releases the resources of this camera.
  @override
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    super.dispose();
    if (_creatingCompleter != null) {
      await _creatingCompleter!.future;
      await _channel.invokeMethod<void>(
        'dispose',
        <String, dynamic>{'textureId': _textureId},
      );
      await _eventSubscription?.cancel();
    }
  }


}
