# Recorder Weather Recorder for macOS

A native, consent-first menu-bar app for recording interview practice and interviews when every participant has explicitly agreed.

## What it records

- Main display at a maximum canvas of 1280×720 and 15 frames per second
- System/meeting audio
- Default microphone
- Apple VideoToolbox hardware-accelerated HEVC/H.265 in an MP4 container
- A strict 572 kbps total meeting profile (500 kbps video plus speech-optimized audio)
- A projected size of about 22 MB for 5 minutes or 263 MB for 1 hour, rather than about 120 MB for 5 minutes
- Black letterboxing when the display is not 16:9, which avoids stretching the picture

The compression profile is optimized for interviews, calls, shared documents, and mostly static screen content. HEVC playback is supported by current Apple platforms and modern players; very old devices or software may require conversion to H.264, which produces a larger file at equivalent quality.

Recordings are saved in `/Library/Application Support/screensessions`.

## Controls

- Press **Option–Command–R** anywhere to start or stop.
- Starting always shows a consent confirmation.
- While recording, the menu-bar icon is red and a persistent **RECORDING** timer is visible.
- The app plays a sound when recording starts and stops.

## Build and run

```sh
./scripts/build_app.sh
open "dist/Recorder Weather Recorder.app"
```

## Test, build, and replace the installed application

Run one command from the project folder:

```sh
./scripts/install_app.sh
```

The installation script:

1. Runs all automated tests.
2. Creates and signs the Release application using the stable Apple signing identity.
3. Verifies the built signature.
4. Refuses to continue if an MP4 recording is currently active.
5. Stops an idle installed copy safely.
6. Copies the new build to `/Applications/Recorder Weather Recorder.app`.
7. Verifies the installed signature.
8. Relaunches the app and confirms that its process remains running.

If permission is genuinely missing when you try to start, the app opens its permission guide. macOS requires the user to personally approve:

1. **Screen & System Audio Recording**
2. **Microphone**

The build script uses a stable Apple code-signing identity so rebuilding does not change the app's identity and invalidate an existing permission grant. It deliberately refuses ad-hoc signing. If macOS asks, quit and reopen the app after changing Screen Recording permission. Privacy controls cannot be bypassed or approved programmatically.

## Start at login

Choose **Start at Login** from the menu-bar menu. The app has no Dock icon and continues to run as a menu-bar app.

## Recording responsibility

Tell every participant what will be recorded and obtain explicit agreement before pressing Start. Laws, company policies, and meeting-platform rules vary by location and organization. This app deliberately does not hide its status, disguise itself, suppress macOS privacy indicators, or bypass system permissions.
