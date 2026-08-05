import AVFoundation
import DeskPetCore
import Foundation

@MainActor
protocol PetSoundPlaying: AnyObject {
    func play(_ profile: PetSoundProfile)
    func stop()
}

@MainActor
final class PetSoundPlayer: PetSoundPlaying {
    private var player: AVAudioPlayer?
    private var cleanupTask: Task<Void, Never>?
    private var generation = 0

    func play(_ profile: PetSoundProfile) {
        do {
            let player = try AVAudioPlayer(data: Self.waveData(for: profile))
            player.prepareToPlay()
            player.play()
            self.player = player
            generation += 1
            let activeGeneration = generation
            cleanupTask?.cancel()
            cleanupTask = Task { [weak self] in
                try? await Task.sleep(
                    for: .seconds(profile.duration + 0.08)
                )
                guard !Task.isCancelled,
                      self?.generation == activeGeneration else { return }
                self?.player = nil
                self?.cleanupTask = nil
            }
        } catch {
            player = nil
        }
    }

    func stop() {
        cleanupTask?.cancel()
        cleanupTask = nil
        generation += 1
        player?.stop()
        player = nil
    }

    private static func waveData(for profile: PetSoundProfile) -> Data {
        let sampleRate = 44_100
        let sampleCount = max(1, Int(profile.duration * Double(sampleRate)))
        var samples = Data(capacity: sampleCount * MemoryLayout<Int16>.size)
        var phase = 0.0

        for index in 0..<sampleCount {
            let progress = Double(index) / Double(max(1, sampleCount - 1))
            let frequency = profile.startFrequency
                + (profile.endFrequency - profile.startFrequency) * progress
            phase += 2 * Double.pi * frequency / Double(sampleRate)

            let attack = min(1, progress / 0.08)
            let release = min(1, (1 - progress) / 0.34)
            let envelope = attack * release
            let fundamental = sin(phase)
            let harmonic = sin(phase * 2) * profile.harmonicMix
            let normalized = (fundamental + harmonic)
                / (1 + profile.harmonicMix)
            let value = max(-1, min(
                1,
                normalized * envelope * profile.amplitude
            ))
            samples.appendLittleEndian(
                Int16((value * Double(Int16.max)).rounded())
            )
        }

        var wave = Data()
        wave.append(contentsOf: "RIFF".utf8)
        wave.appendLittleEndian(UInt32(36 + samples.count))
        wave.append(contentsOf: "WAVE".utf8)
        wave.append(contentsOf: "fmt ".utf8)
        wave.appendLittleEndian(UInt32(16))
        wave.appendLittleEndian(UInt16(1))
        wave.appendLittleEndian(UInt16(1))
        wave.appendLittleEndian(UInt32(sampleRate))
        wave.appendLittleEndian(UInt32(sampleRate * 2))
        wave.appendLittleEndian(UInt16(2))
        wave.appendLittleEndian(UInt16(16))
        wave.append(contentsOf: "data".utf8)
        wave.appendLittleEndian(UInt32(samples.count))
        wave.append(samples)
        return wave
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) {
            append(contentsOf: $0)
        }
    }
}
