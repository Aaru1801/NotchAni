import CoreAudio
import Foundation

final class AudioMonitor {
    typealias VolumeHandler = (Float, Bool) -> Void
    typealias DeviceHandler = (String?) -> Void

    private let onVolume: VolumeHandler
    private let onDevice: DeviceHandler

    private var currentDeviceID: AudioDeviceID = AudioDeviceID(kAudioObjectUnknown)
    private let queue = DispatchQueue(label: "NotchAni.AudioMonitor")

    private var volumeListener: AudioObjectPropertyListenerBlock?
    private var muteListener: AudioObjectPropertyListenerBlock?
    private var deviceListener: AudioObjectPropertyListenerBlock?

    init(onVolume: @escaping VolumeHandler, onDevice: @escaping DeviceHandler) {
        self.onVolume = onVolume
        self.onDevice = onDevice
    }

    func start() {
        attachDefaultDeviceListener()
        refreshDefaultDevice(initial: true)
    }

    deinit {
        removeDeviceListeners()
    }

    private func attachDefaultDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.refreshDefaultDevice(initial: false)
        }
        deviceListener = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            queue,
            block
        )
    }

    private func refreshDefaultDevice(initial: Bool) {
        let id = fetchDefaultOutputDevice()
        guard id != currentDeviceID else { return }
        removeDeviceListeners()
        currentDeviceID = id
        installDeviceListeners()
        let name = deviceName(id)
        onDevice(initial ? nil : name)
    }

    private func fetchDefaultOutputDevice() -> AudioDeviceID {
        var id: AudioDeviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &id
        )
        return id
    }

    private func deviceName(_ id: AudioDeviceID) -> String? {
        guard id != AudioDeviceID(kAudioObjectUnknown) else { return nil }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfName: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &cfName)
        guard status == noErr, let cfName else { return nil }
        return cfName.takeRetainedValue() as String
    }

    private func installDeviceListeners() {
        guard currentDeviceID != AudioDeviceID(kAudioObjectUnknown) else { return }

        let volumeBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.emit()
        }
        volumeListener = volumeBlock

        for channel in volumeChannels() {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: channel
            )
            if AudioObjectHasProperty(currentDeviceID, &address) {
                AudioObjectAddPropertyListenerBlock(currentDeviceID, &address, queue, volumeBlock)
            }
        }

        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let muteBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.emit()
        }
        muteListener = muteBlock
        if AudioObjectHasProperty(currentDeviceID, &muteAddress) {
            AudioObjectAddPropertyListenerBlock(currentDeviceID, &muteAddress, queue, muteBlock)
        }
    }

    private func removeDeviceListeners() {
        guard currentDeviceID != AudioDeviceID(kAudioObjectUnknown) else { return }

        if let block = volumeListener {
            for channel in volumeChannels() {
                var address = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: channel
                )
                if AudioObjectHasProperty(currentDeviceID, &address) {
                    AudioObjectRemovePropertyListenerBlock(currentDeviceID, &address, queue, block)
                }
            }
        }
        if let block = muteListener {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectHasProperty(currentDeviceID, &address) {
                AudioObjectRemovePropertyListenerBlock(currentDeviceID, &address, queue, block)
            }
        }
        volumeListener = nil
        muteListener = nil
    }

    private func volumeChannels() -> [UInt32] {
        [kAudioObjectPropertyElementMain, 1, 2]
    }

    private func emit() {
        let device = currentDeviceID
        guard device != AudioDeviceID(kAudioObjectUnknown) else { return }
        let volume = readVolume(device) ?? 0
        let muted = readMute(device) ?? false
        onVolume(volume, muted)
    }

    private func readVolume(_ device: AudioDeviceID) -> Float? {
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(device, &address),
           AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr {
            return value
        }

        var sum: Float32 = 0
        var count: Int = 0
        for channel: UInt32 in [1, 2] {
            address.mElement = channel
            if AudioObjectHasProperty(device, &address) {
                size = UInt32(MemoryLayout<Float32>.size)
                if AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr {
                    sum += value
                    count += 1
                }
            }
        }
        return count > 0 ? sum / Float(count) : nil
    }

    private func readMute(_ device: AudioDeviceID) -> Bool? {
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(device, &address),
           AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted) == noErr {
            return muted != 0
        }
        return nil
    }
}
