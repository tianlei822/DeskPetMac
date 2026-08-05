import Foundation
import Testing

@Suite("Pet visual baseline")
struct PetVisualBaselineTests {
  @Test("fingerprints are compact and deterministic")
  @MainActor
  func fingerprintsStayDeterministic() throws {
    let snapshot = PetVisualSnapshotCase(
      petKind: .dog,
      state: .toy,
      weather: .rainy,
      appearance: .dark,
      motionSetting: .full
    )
    let pngData = try PetVisualSnapshotRenderer.pngData(for: snapshot)
    let first = try PetVisualFingerprint.make(pngData: pngData)
    let second = try PetVisualFingerprint.make(pngData: pngData)

    #expect(first == second)
    #expect(first.pixelsWide == 260)
    #expect(first.pixelsHigh == 290)
    #expect(first.signature.count == PetVisualFingerprint.signatureByteCount)
    #expect(first.signature.count < 1_000)
  }

  @Test("difference policy tolerates tiny drift and rejects local regressions")
  func differencePolicySeparatesNoiseFromRegression() {
    let byteCount = PetVisualFingerprint.signatureByteCount
    let reference = PetVisualFingerprint(
      pixelsWide: 260,
      pixelsHigh: 290,
      signature: Data(repeating: 128, count: byteCount)
    )
    let tinyDrift = PetVisualFingerprint(
      pixelsWide: 260,
      pixelsHigh: 290,
      signature: Data(repeating: 130, count: byteCount)
    )
    var changedBytes = [UInt8](repeating: 128, count: byteCount)
    changedBytes[0] = 255
    changedBytes[1] = 255
    changedBytes[2] = 255
    let localRegression = PetVisualFingerprint(
      pixelsWide: 260,
      pixelsHigh: 290,
      signature: Data(changedBytes)
    )

    let drift = PetVisualFingerprintDifference.compare(
      reference: reference,
      candidate: tinyDrift
    )
    let regression = PetVisualFingerprintDifference.compare(
      reference: reference,
      candidate: localRegression
    )

    #expect(PetVisualBaselinePolicy.accepts(drift))
    #expect(!PetVisualBaselinePolicy.accepts(regression))
    #expect(regression.maximumBlockError > drift.maximumBlockError)
  }

  @Test("baseline manifest round trips with stable sorted records")
  func baselineManifestRoundTrips() throws {
    let records = ["z.png", "a.png"].map { name in
      PetVisualBaselineRecord(
        artifactName: name,
        fingerprint: PetVisualFingerprint(
          pixelsWide: 260,
          pixelsHigh: 290,
          signature: Data(
            repeating: UInt8(name == "a.png" ? 1 : 2),
            count: PetVisualFingerprint.signatureByteCount
          )
        )
      )
    }
    let manifest = PetVisualBaselineManifest(records: records)
    let encoded = try manifest.encoded()
    let decoded = try PetVisualBaselineManifest.decode(encoded)

    #expect(decoded == manifest)
    #expect(decoded.records.map(\.artifactName) == ["a.png", "z.png"])
    #expect(encoded.last == 0x0A)
  }

  @Test("verification catches a changed block from a real rendering")
  @MainActor
  func verificationDetectsRenderedRegression() throws {
    let snapshot = PetVisualSnapshotCase(
      petKind: .cat,
      state: .idle,
      weather: .cozy,
      appearance: .light,
      motionSetting: .reduced
    )
    let data = try PetVisualSnapshotRenderer.pngData(for: snapshot)
    let current = try PetVisualFingerprint.make(pngData: data)
    var changedBytes = [UInt8](current.signature)
    for index in 0..<3 {
      changedBytes[index] = changedBytes[index] < 128 ? 255 : 0
    }
    let changed = PetVisualFingerprint(
      pixelsWide: current.pixelsWide,
      pixelsHigh: current.pixelsHigh,
      signature: Data(changedBytes)
    )
    let manifest = PetVisualBaselineManifest(records: [
      PetVisualBaselineRecord(
        artifactName: snapshot.artifactName,
        fingerprint: changed
      )
    ])

    let failures = try PetVisualBaselineVerifier.verify(
      manifest: manifest,
      snapshots: [snapshot]
    )
    #expect(failures.count == 1)
    #expect(failures[0].contains(snapshot.artifactName))
  }

  @Test("checked-in baseline covers the complete visual matrix")
  func checkedInBaselineIsComplete() throws {
    guard
      ProcessInfo.processInfo.environment[
        "DESKPET_VISUAL_BASELINE_UPDATE"
      ] == nil
    else {
      return
    }

    let manifest = try PetVisualBaselineManifest.load(
      from: PetVisualBaselineManifest.defaultURL
    )
    #expect(
      manifest.records.count
        == PetVisualSnapshotCase.standardMatrix.count
    )
    #expect(
      Set(manifest.records.map(\.artifactName))
        == Set(
          PetVisualSnapshotCase.standardMatrix.map(\.artifactName)
        ))
  }

  @Test("full matrix can update an explicit baseline")
  @MainActor
  func updatesBaselineOnDemand() throws {
    guard
      let rawOutput = ProcessInfo.processInfo.environment[
        "DESKPET_VISUAL_BASELINE_UPDATE"
      ], !rawOutput.isEmpty
    else {
      return
    }

    let output = URL(fileURLWithPath: rawOutput, isDirectory: false)
    let manifest = try PetVisualBaselineVerifier.makeCurrentManifest()
    try manifest.write(to: output)
    #expect(
      manifest.records.count
        == PetVisualSnapshotCase.standardMatrix.count
    )
  }

  @Test("full matrix matches the checked-in baseline when enabled")
  @MainActor
  func verifiesBaselineOnDemand() throws {
    guard
      ProcessInfo.processInfo.environment[
        "DESKPET_VISUAL_BASELINE_VERIFY"
      ] == "1"
    else {
      return
    }

    let manifest = try PetVisualBaselineManifest.load(
      from: PetVisualBaselineManifest.defaultURL
    )
    let failures = try PetVisualBaselineVerifier.verify(manifest: manifest)
    #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
  }
}
