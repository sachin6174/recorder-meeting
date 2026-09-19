# Recorder Weather Recorder — Operating Guide

This guide explains how to install, operate, and verify the compressed meeting recorder on macOS.

## What the recorder does

The application records:

- The main Mac display at up to 1280×720 resolution
- System and meeting audio
- The default microphone
- The mouse pointer and mouse clicks

New recordings use hardware-accelerated HEVC/H.265 compression. The profile is designed for interviews, meetings, shared documents, and programming screens.

Expected approximate file sizes:

| Recording duration | Expected size |
| ---: | ---: |
| 5 minutes | About 22 MB |
| 15 minutes | About 66 MB |
| 30 minutes | About 131 MB |
| 45 minutes | About 197 MB |
| 1 hour | About 263 MB |

Actual size can vary with screen movement, audio, and MP4 container overhead. Mostly static screens may produce smaller files.

## Important consent requirement

Before starting a recording:

1. Tell every participant that the screen, meeting audio, and microphone will be recorded.
2. Obtain clear permission from every participant.
3. Follow the applicable laws, workplace rules, and meeting-platform policies.

Do not record anyone without their knowledge and permission.

## First-time installation

The current release is already installed at:

```text
/Applications/Recorder Weather Recorder.app
```

To rebuild and reinstall it after making source-code changes:

1. Open Terminal.
2. Change to the project folder:

   ```sh
   cd "/Users/sachinkumar/Desktop/recorder-meeting"
   ```

3. Run the installation script:

   ```sh
   ./scripts/install_app.sh
   ```

4. Wait for the `Installed successfully` message.

The script runs the tests, creates the Release build, signs it, installs it in Applications, and launches it.

The installation script will refuse to replace the app while a recording is active. Stop and finalize the recording first, and then run the script again.

## Grant permissions

macOS requires two permissions:

1. **Screen & System Audio Recording**
2. **Microphone**

If the app opens its permission guide:

1. Open **System Settings**.
2. Select **Privacy & Security**.
3. Open **Screen & System Audio Recording**.
4. Enable **Recorder Weather Recorder**.
5. Return to **Privacy & Security**.
6. Open **Microphone**.
7. Enable **Recorder Weather Recorder**.
8. Quit and reopen the application if macOS requests it.

The app cannot approve these permissions automatically. You must approve them personally in System Settings.

## Launch the recorder

1. Open **Finder**.
2. Select **Applications** in the sidebar.
3. Double-click **Recorder Weather Recorder**.
4. Look for the cloud icon in the macOS menu bar.

The application has no normal Dock window. It operates from the menu bar and through its global keyboard shortcut.

## Start a recording

Before starting, confirm that every participant has agreed to the recording.

Use either method:

### Keyboard shortcut

Press:

```text
Option–Command–R
```

This shortcut works even when another application is active.

### Menu-bar control

1. Click the cloud icon in the macOS menu bar.
2. Click **Toggle**.

When recording begins:

- The app plays a sound.
- The menu-bar icon changes to a red recording icon.
- The app begins writing a compressed MP4 file.

If the icon does not change, click the menu-bar icon and check whether macOS permissions are missing.

## During a recording

1. Keep the recorder application running.
2. Continue using the meeting or interview application normally.
3. Avoid repeatedly starting and stopping the recorder.
4. Do not reinstall or replace the app while recording.
5. Do not force-quit the app or shut down the Mac before stopping the recording.

The compression happens while recording. There is no long post-recording compression step after you press Stop.

For the best balance between readability and small size:

- Keep shared text at a comfortable readable size.
- Avoid unnecessary rapid scrolling.
- Avoid playing full-screen high-motion videos when they are not needed.
- Use a clear microphone and normal speaking volume.

Rapid animation and full-screen video can look softer because this recorder deliberately prioritizes small meeting files.

## Stop and save a recording

Use either method:

### Keyboard shortcut

Press again:

```text
Option–Command–R
```

### Menu-bar control

1. Click the red recording icon in the menu bar.
2. Click **Toggle**.

After stopping:

1. Wait for the stop sound.
2. Wait until the red icon returns to the normal cloud icon.
3. Allow the application a few seconds to finalize a long MP4 file before quitting the app or shutting down the Mac.

## Find the saved recording

The recorder first attempts to save recordings in:

```text
/Library/Application Support/screensessions
```

If macOS does not permit writing there, it automatically uses the current user's folder:

```text
~/Library/Application Support/screensessions
```

On the current installation, recordings are normally found in:

```text
/Users/sachinkumar/Library/Application Support/screensessions
```

To open that folder:

1. Open **Finder**.
2. In the menu bar, select **Go** → **Go to Folder…**.
3. Paste:

   ```text
   /Users/sachinkumar/Library/Application Support/screensessions
   ```

4. Press **Return**.

Files use names similar to:

```text
screensession-2026-08-26_13-07-53.mp4
```

The date and time in the filename identify when the recording started.

## Play and verify a recording

After every important recording:

1. Open the `screensessions` folder.
2. Sort by **Date Modified**.
3. Open the newest MP4 in QuickTime Player.
4. Check the beginning, middle, and end of the recording.
5. Confirm that the screen is visible and readable.
6. Confirm that meeting/system audio is present.
7. Confirm that microphone audio is present.
8. Confirm that the duration is correct.
9. Check the file size in Finder by selecting the file and pressing **Command–I**.

Do not delete the original recording until you have checked both its video and audio.

## HEVC/H.265 compatibility

The small file size is achieved using HEVC/H.265 instead of the older H.264 codec.

Recommended playback applications:

- QuickTime Player on current macOS versions
- Current Apple Photos and Finder preview
- Current versions of VLC
- Modern editing software with HEVC support

Very old computers, browsers, Windows players, or editing applications may not support HEVC. If another person cannot play a recording, convert a copy to H.264 while keeping the original HEVC file. The H.264 copy will normally be larger.

## Quit the recorder

1. Make sure no recording is active.
2. Click the cloud icon in the menu bar.
3. Click **Quit**.

If you attempt to quit while recording, allow the application to stop and finalize the recording before it closes.

## Troubleshooting

### The keyboard shortcut does nothing

1. Confirm that Recorder Weather Recorder is running.
2. Look for its cloud icon in the menu bar.
3. Open the menu and use **Toggle**.
4. Check Screen Recording and Microphone permissions.
5. Quit and reopen the app after changing permissions.

### The app shows that a permission is missing

Open:

```text
System Settings → Privacy & Security
```

Enable the app under both **Screen & System Audio Recording** and **Microphone**, and then reopen the app.

### No recording appears in the system folder

Check the user fallback folder:

```text
/Users/sachinkumar/Library/Application Support/screensessions
```

### The MP4 file will not open

1. Confirm that the recording was stopped normally.
2. Try opening it in the latest QuickTime Player or VLC.
3. Check that the file size is greater than zero.
4. Avoid moving or copying the file while the red recording icon is active.

### The file is still larger than expected

Check the following:

1. Confirm that the newest installed version is running from `/Applications/Recorder Weather Recorder.app`.
2. Confirm that the file is a new recording created after the HEVC compression update.
3. Check whether the recording contains constant full-screen motion or video playback.
4. Verify that the file duration is what you expected.

Old recordings are not automatically recompressed. Only recordings created with the updated application use the new HEVC profile.

### The picture becomes soft during movement

The 572 kbps profile is intentionally optimized for small meeting files. Fast motion, gaming, animation, or full-screen video can exceed this quality budget. For interviews, calls, documents, and programming screens, keep movement moderate and shared text readable.

### Read the diagnostic log

If recording still fails, open Terminal and run:

```sh
tail -100 "$HOME/Library/Logs/InterviewRecorder/recorder.log"
```

Look for the newest `Start failed`, `Capture stream stopped`, or compression-related message.

## Recommended operating checklist

### Before the meeting

- [ ] Every participant has agreed to the recording.
- [ ] Recorder Weather Recorder is running.
- [ ] The cloud icon is visible in the menu bar.
- [ ] Screen Recording permission is enabled.
- [ ] Microphone permission is enabled.
- [ ] Enough free disk space is available.
- [ ] A short test recording has been checked for screen and audio.

### Start

- [ ] Press Option–Command–R or click **Toggle**.
- [ ] Confirm that the icon becomes red.
- [ ] Confirm that the start sound plays.

### Stop

- [ ] Press Option–Command–R or click **Toggle** again.
- [ ] Wait for the stop sound.
- [ ] Wait for the normal cloud icon to return.

### Verify

- [ ] Open the newest MP4.
- [ ] Check video at the beginning, middle, and end.
- [ ] Check meeting audio.
- [ ] Check microphone audio.
- [ ] Check duration.
- [ ] Check file size.
- [ ] Back up the recording if it is important.
