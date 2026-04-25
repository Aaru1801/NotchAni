import AppKit
import CoreAudio
import Foundation

enum SystemAdjuster {
    static func setVolume(_ value: Float) {
        let device = defaultOutputDevice()
        guard device != AudioDeviceID(kAudioObjectUnknown) else { return }
        var v: Float32 = max(0, min(1, value))

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(device, &address) {
            AudioObjectSetPropertyData(device, &address, 0, nil,
                                       UInt32(MemoryLayout<Float32>.size), &v)
        }
        for channel: UInt32 in [1, 2] {
            address.mElement = channel
            if AudioObjectHasProperty(device, &address) {
                AudioObjectSetPropertyData(device, &address, 0, nil,
                                           UInt32(MemoryLayout<Float32>.size), &v)
            }
        }

        // If audio is muted but we're scrubbing up, unmute.
        if v > 0 {
            setMuted(false, device: device)
        }
    }

    static func setMuted(_ muted: Bool) {
        setMuted(muted, device: defaultOutputDevice())
    }

    static func setBrightness(_ value: Float) {
        guard let setter = BrightnessWriter.setBrightness else { return }
        let v = max(0, min(1, value))
        for screen in NSScreen.screens {
            if let id = displayID(for: screen) {
                _ = setter(id, v)
            }
        }
    }

    private static func setMuted(_ muted: Bool, device: AudioDeviceID) {
        guard device != AudioDeviceID(kAudioObjectUnknown) else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = muted ? 1 : 0
        if AudioObjectHasProperty(device, &address) {
            AudioObjectSetPropertyData(device, &address, 0, nil,
                                       UInt32(MemoryLayout<UInt32>.size), &value)
        }
    }

    private static func defaultOutputDevice() -> AudioDeviceID {
        var id: AudioDeviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                   &address, 0, nil, &size, &id)
        return id
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }
}

private enum BrightnessWriter {
    typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    static let handle: UnsafeMutableRawPointer? = {
        dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
    }()

    static let setBrightness: SetBrightness? = {
        guard let handle, let p = dlsym(handle, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(p, to: SetBrightness.self)
    }()
}
