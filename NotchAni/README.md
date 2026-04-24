# NotchAni

Replaces the top-right macOS volume and brightness HUD with an animated black pill that grows out of the MacBook notch — like a Dynamic Island for the Mac. Suppresses the system HUD automatically, shows song-change and AirPods-connect notifications, and expands into a full media + sliders panel on hover.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode command-line tools (`xcode-select --install`)
- Designed for notched MacBooks. On notchless Macs it anchors to the top-center of the primary display.

## Run

```bash
swift run -c release
```

Or build an installable `.app`:

```bash
./scripts/build-app.sh
open NotchAni.app
```

NotchAni runs as a menu-bar accessory. Look for the notch-shaped icon in your menu bar to preview states or quit.

## What it does

| Trigger | Behavior |
| --- | --- |
| Volume key (F10–F12) or slider change | Notch grows into a notch-wide pill with icon + big % + progress bar. Auto-collapses after 1.6 s. |
| Brightness key (F1/F2) | Same, tinted amber. |
| Song change (any app using `MediaRemote`: Music, Spotify, Safari, etc.) | Song title + artist + album art slide out below the notch. Auto-collapses. |
| AirPods / output device change | Device name + icon appears under the notch. |
| Hover over the notch | Single haptic tick, then expands into a full panel: left half is album art + title/artist + timeline + previous/play-pause/next buttons; right half is VOLUME and BRIGHTNESS sliders with large percentages. Click the buttons to control playback. |
| Mouse leaves the panel | Panel collapses back into the notch. |

The system's own translucent volume/brightness HUD is continuously `SIGSTOP`ed (every 100 ms) so it never draws. On quit the app sends `SIGCONT` to restore default behavior.

## If the system HUD stays suppressed after a crash

NotchAni only restores `OSDUIHelper` on a clean quit (menu → Quit NotchAni, or `applicationWillTerminate`). If the app is force-killed, resume it manually:

```bash
pkill -CONT OSDUIHelper
```

Or simply relaunch NotchAni and quit it cleanly.

## How it works

- **Overlay window** — borderless, non-activating `NSPanel` at `overlayWindow` level, present on all Spaces / fullscreen. Flips `ignoresMouseEvents` to `false` when the panel is expanded so the media buttons can be clicked.
- **Volume + device monitoring** — Core Audio property listeners on `kAudioDevicePropertyVolumeScalar` + `kAudioDevicePropertyMute`. When the default output device changes, we read `kAudioObjectPropertyName` and fire a "connected" notification.
- **Brightness monitoring** — `dlopen`s `DisplayServices.framework` and polls `DisplayServicesGetBrightness` on a 100 ms timer.
- **Media info** — `dlopen`s `MediaRemote.framework`, calls `MRMediaRemoteRegisterForNowPlayingNotifications`, observes the four `kMRMediaRemoteNowPlaying…DidChangeNotification`s, and calls `MRMediaRemoteGetNowPlayingInfo` to pull title/artist/artwork/elapsed/duration. Playback commands go back through `MRMediaRemoteSendCommand`.
- **Hover** — global `NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)` watches `NSEvent.mouseLocation`. When the cursor enters a hot zone anchored to the notch, fires `NSHapticFeedbackManager.perform(.alignment)` and transitions the view model to `.expanded`. The hot zone grows with the panel so you can move inside it freely.
- **HUD suppression** — enumerates pids via `proc_listallpids` / `proc_pidpath` every 100 ms and sends `SIGSTOP` to `OSDUIHelper`. `launchd` sees the process as still running so it doesn't respawn, and the suspended process can't draw.
- **Animation** — one shared flat-top / rounded-bottom `NotchShape`, SwiftUI spring animations on the size change, content cross-fades with a short delay so the shape expands first and text settles in after.

## File layout

```
Package.swift
Sources/NotchAni/
  NotchAniApp.swift         @main entry
  AppDelegate.swift         lifecycle, menu bar
  NotchController.swift     wires monitors + view model + hover
  NotchViewModel.swift      state machine + data types
  NotchWindow.swift         NSPanel over the notch
  NotchRootView.swift       SwiftUI views for idle / hud / notification / expanded
  AudioMonitor.swift        Core Audio volume + device listener
  BrightnessMonitor.swift   DisplayServices poller
  MediaRemoteMonitor.swift  MediaRemote private-framework wrapper
  HoverMonitor.swift        global mouse-moved watcher
  SystemHUDSuppressor.swift SIGSTOP loop for OSDUIHelper
scripts/build-app.sh        package into NotchAni.app
```
