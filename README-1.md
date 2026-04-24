# NotchAni 🚧 (Work in Progress)

**NotchAni** aims to replace the top-right macOS volume and brightness HUD with an animated black pill that grows out of the MacBook notch — like a Dynamic Island for the Mac. It runs as a menu-bar accessory. Look for the notch-shaped icon in your menu bar to preview states or quit.

> **⚠️ Current Development Status**
> This app is currently under active development. Please note the following known limitations:
> * **System HUD Suppression is WIP:** The default macOS volume/brightness pill on the top right currently still appears alongside NotchAni. I'm still figuring out how to completely suppress it. 
> * **Media Capabilities are WIP:** Features involving `MediaRemote` (like song-change notifications, album art, and expanded playback controls) are currently under development and may not function entirely yet.

## Installation

No terminal commands or manual builds required! Simply download the latest `NotchAni.app` from the **Releases** section of this repository, unzip it, and drag it into your Applications folder.

## Requirements

- macOS 14 (Sonoma) or later
- Designed for notched MacBooks. On notchless Macs, it anchors to the top-center of the primary display.

## Intended Features (What it does)

| Trigger | Behavior |
| --- | --- |
| Volume key (F10–F12) or slider change | Notch grows into a notch-wide pill with icon + big % + progress bar. Auto-collapses after 1.6 s. |
| Brightness key (F1/F2) | Same, tinted amber. |
| Song change *(WIP)* | Song title + artist + album art slide out below the notch. Auto-collapses. |
| AirPods / output device change | Device name + icon appears under the notch. |
| Hover over the notch *(WIP)* | Single haptic tick, then expands into a full panel: left half is album art + title/artist + timeline + previous/play-pause/next buttons; right half is VOLUME and BRIGHTNESS sliders with large percentages. Click the buttons to control playback. |
| Mouse leaves the panel | Panel collapses back into the notch. |

## How it works

- **Overlay window** — borderless, non-activating `NSPanel` at `overlayWindow` level, present on all Spaces / fullscreen. Flips `ignoresMouseEvents` to `false` when the panel is expanded so the media buttons can be clicked.
- **Volume + device monitoring** — Core Audio property listeners on `kAudioDevicePropertyVolumeScalar` + `kAudioDevicePropertyMute`. When the default output device changes, we read `kAudioObjectPropertyName` and fire a "connected" notification.
- **Brightness monitoring** — `dlopen`s `DisplayServices.framework` and polls `DisplayServicesGetBrightness` on a 100 ms timer.
- **Media info (WIP)** — `dlopen`s `MediaRemote.framework`, calls `MRMediaRemoteRegisterForNowPlayingNotifications`, observes the four `kMRMediaRemoteNowPlaying…DidChangeNotification`s, and calls `MRMediaRemoteGetNowPlayingInfo` to pull title/artist/artwork/elapsed/duration. Playback commands go back through `MRMediaRemoteSendCommand`.
- **Hover** — global `NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)` watches `NSEvent.mouseLocation`. When the cursor enters a hot zone anchored to the notch, fires `NSHapticFeedbackManager.perform(.alignment)` and transitions the view model to `.expanded`. The hot zone grows with the panel so you can move inside it freely.
- **HUD suppression (WIP)** — The current approach involves enumerating pids via `proc_listallpids` / `proc_pidpath` every 100 ms and sending `SIGSTOP` to `OSDUIHelper` (with `SIGCONT` sent on quit). This is actively being tweaked to reliably prevent the system HUD from drawing.
- **Animation** — one shared flat-top / rounded-bottom `NotchShape`, SwiftUI spring animations on the size change, content cross-fades with a short delay so the shape expands first and text settles in after.

## File layout

```text
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
  SystemHUDSuppressor.swift SIGSTOP loop for OSDUIHelper (WIP)
```