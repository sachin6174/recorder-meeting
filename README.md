# Interview Recorder for macOS

A native, consent-first menu-bar app for recording interview practice and interviews when every participant has explicitly agreed.

## What it records

- Main display at a maximum canvas of 1280×720 and 30 frames per second
- System/meeting audio
- Default microphone
- Hardware-accelerated H.264 in an MP4 container for reliable, compact 720p output
- Black letterboxing when the display is not 16:9, which avoids stretching the picture

Recordings are saved in `~/Movies/Interview Recordings`.

## Controls

- Press **Option–Command–R** anywhere to start or stop.
- Starting always shows a consent confirmation.
- While recording, the menu-bar icon is red and a persistent **RECORDING** timer is visible.
- The app plays a sound when recording starts and stops.

## Build and run

```sh
./scripts/build_app.sh
open "dist/Interview Recorder.app"
```

If permission is genuinely missing when you try to start, the app opens its permission guide. macOS requires the user to personally approve:

1. **Screen & System Audio Recording**
2. **Microphone**

The build script uses a stable Apple code-signing identity so rebuilding does not change the app's identity and invalidate an existing permission grant. It deliberately refuses ad-hoc signing. If macOS asks, quit and reopen the app after changing Screen Recording permission. Privacy controls cannot be bypassed or approved programmatically.

## Start at login

Choose **Start at Login** from the menu-bar menu. The app has no Dock icon and continues to run as a menu-bar app.

## Recording responsibility

Tell every participant what will be recorded and obtain explicit agreement before pressing Start. Laws, company policies, and meeting-platform rules vary by location and organization. This app deliberately does not hide its status, disguise itself, suppress macOS privacy indicators, or bypass system permissions.
