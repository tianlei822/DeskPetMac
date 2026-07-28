import Foundation

/// Irregular, deterministic lightning for stormy weather. Each cycle (one
/// `period`) fires 1-3 short pulses at a hashed onset, spacing, and bolt
/// shape, so flashes feel like weather instead of a metronome.
public enum StormLightningSchedule {
    /// Peak visual intensity; matches the previous fixed flash brightness.
    public static let peakIntensity = 0.2

    /// Combined flash intensity at `time`, in 0...peakIntensity.
    public static func flashIntensity(at time: Double, period: Double) -> Double {
        guard time.isFinite, period > 0 else { return 0 }
        let cycle = floor(time / period)
        let within = time - cycle * period
        guard within.isFinite, within >= 0 else { return 0 }

        let seed = cycleHash(cycle)
        let pulseCount = 1 + Int(seed % 3)
        let firstOnset = (0.05 + unit(seed, shift: 3) * 0.45) * period

        var intensity = 0.0
        for pulse in 0..<pulseCount {
            let pulseSeed = seed &+ UInt64(pulse &+ 1) &* 0x9E3779B97F4A7C15
            let spacing = 0.09 + unit(pulseSeed, shift: 5) * 0.17
            let duration = 0.055 + unit(pulseSeed, shift: 9) * 0.05
            let onset = firstOnset + Double(pulse) * spacing
            let elapsed = within - onset
            guard elapsed >= 0, elapsed < duration else { continue }
            let peak = 1.0 / (1.0 + Double(pulse) * 0.7)
            intensity += (1 - elapsed / duration) * peak
        }
        return min(1, intensity) * peakIntensity
    }

    /// Which bolt silhouette to draw this cycle, and whether to mirror it.
    /// `variantCount` is the number of silhouettes the view provides.
    public static func boltVariant(
        at time: Double,
        period: Double,
        variantCount: Int
    ) -> (index: Int, mirrored: Bool) {
        guard time.isFinite, period > 0, variantCount > 0 else {
            return (0, false)
        }
        let seed = cycleHash(floor(time / period))
        return (Int((seed >> 11) % UInt64(variantCount)), (seed >> 23) & 1 == 1)
    }

    private static func cycleHash(_ cycle: Double) -> UInt64 {
        guard cycle.isFinite else { return 0 }
        let bounded = cycle.truncatingRemainder(dividingBy: 9_007_199_254_740_992)
        var mixed = UInt64(bitPattern: Int64(bounded))
        mixed &+= 0x9E3779B97F4A7C15
        mixed ^= mixed >> 30
        mixed &*= 0xBF58476D1CE4E5B9
        mixed ^= mixed >> 27
        mixed &*= 0x94D049BB133111EB
        mixed ^= mixed >> 31
        return mixed
    }

    private static func unit(_ seed: UInt64, shift: UInt64) -> Double {
        Double((seed >> shift) & 0xFFFF) / Double(0xFFFF)
    }
}
