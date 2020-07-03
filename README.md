# Better Camera Plugin
(NOTE THIS IS A FORK OF THE OFFICIAL CAMERA PLUGIN, FEEL FREE TO USE THIS UNTILL IT SUPPORTS MISSING FEATURES, HERE THE OFFICIAL PLUGIN https://github.com/flutter/plugins)

**(THIS IS QUITE UNSTABLE BUT WE ARE STARTING TO BE MORE ACTIVE DEVELOPING THIS PLUGIN)**

A Flutter plugin for iOS and Android allowing access to the device cameras.

## Dart package
https://pub.flutter-io.cn/packages/flutter_better_camera

## Features:

* Display live camera preview in a widget.
* Snapshots can be captured and saved to a file.
* Record video.
* Add access to the image stream from Dart.
* Flash control
* Zoom control
* Auto exposure on/off
* Auto focus on/off

## Installation

Clone this repo and add it as a dependancy in your flutter pubspec.yaml

### iOS
Add two rows to the `ios/Runner/Info.plist`:

* one with the key `Privacy - Camera Usage Description` and a usage description.
* and one with the key `Privacy - Microphone Usage Description` and a usage description.

Or in text format add the key:

```xml
<key>NSCameraUsageDescription</key>
<string>Can I use the camera please?</string>
<key>NSMicrophoneUsageDescription</key>
<string>Can I use the mic please?</string>
```

### Android

Change the minimum Android sdk version to 21 (or higher) in your `android/app/build.gradle` file.

Modify your AndroidManifest.xml
    
    <uses-permission android:name="android.permission.CAMERA" />    
    <uses-permission android:name="android.permission.FLASHLIGHT" />
    <uses-feature android:name="android.hardware.camera" />
    <uses-feature android:name="android.hardware.camera.front" />
    <uses-feature android:name="android.hardware.camera2" android:required="false" />
    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false"/>
    <uses-feature android:name="android.hardware.camera.flash" android:required="false" />

```
minSdkVersion 21
```

There is aN example for the camera in this repo

## NEXT UP:

* Tap to focus
* Burst mode
* Control the camera preview ratio
* Optimize the quality of images
* Control White balance

FEEL FREE TO ADD ISSUES AND PLEASE CONTRIBUTE
