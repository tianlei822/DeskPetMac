import AppKit
import Foundation

struct PetVisualFingerprint: Codable, Equatable {
  static let gridColumns = 12
  static let gridRows = 14
  static let signatureByteCount = gridColumns * gridRows * 3

  let pixelsWide: Int
  let pixelsHigh: Int
  let signature: Data

  static func make(pngData: Data) throws -> PetVisualFingerprint {
    guard let bitmap = NSBitmapImageRep(data: pngData) else {
      throw PetVisualBaselineError.invalidPNG
    }

    var signature = Data(capacity: signatureByteCount)
    for row in 0..<gridRows {
      let minimumY = row * bitmap.pixelsHigh / gridRows
      let maximumY = max(
        minimumY + 1,
        (row + 1) * bitmap.pixelsHigh / gridRows
      )
      for column in 0..<gridColumns {
        let minimumX = column * bitmap.pixelsWide / gridColumns
        let maximumX = max(
          minimumX + 1,
          (column + 1) * bitmap.pixelsWide / gridColumns
        )
        let points = samplePoints(
          minimumX: minimumX,
          maximumX: maximumX,
          minimumY: minimumY,
          maximumY: maximumY
        )
        var red = 0.0
        var green = 0.0
        var blue = 0.0
        for point in points {
          guard
            let color = bitmap.colorAt(x: point.x, y: point.y)?
              .usingColorSpace(.deviceRGB)
          else {
            throw PetVisualBaselineError.unreadablePixel
          }
          red += color.redComponent
          green += color.greenComponent
          blue += color.blueComponent
        }
        let divisor = Double(points.count)
        signature.append(quantize(red / divisor))
        signature.append(quantize(green / divisor))
        signature.append(quantize(blue / divisor))
      }
    }

    return PetVisualFingerprint(
      pixelsWide: bitmap.pixelsWide,
      pixelsHigh: bitmap.pixelsHigh,
      signature: signature
    )
  }

  private static func samplePoints(
    minimumX: Int,
    maximumX: Int,
    minimumY: Int,
    maximumY: Int
  ) -> [(x: Int, y: Int)] {
    let width = max(1, maximumX - minimumX)
    let height = max(1, maximumY - minimumY)
    let x1 = min(maximumX - 1, minimumX + width / 3)
    let x2 = min(maximumX - 1, minimumX + width * 2 / 3)
    let y1 = min(maximumY - 1, minimumY + height / 3)
    let y2 = min(maximumY - 1, minimumY + height * 2 / 3)
    return [(x1, y1), (x2, y1), (x1, y2), (x2, y2)]
  }

  private static func quantize(_ component: Double) -> UInt8 {
    UInt8(min(255, max(0, Int((component * 255).rounded()))))
  }
}

struct PetVisualFingerprintDifference: Equatable {
  let dimensionsMatch: Bool
  let meanAbsoluteError: Double
  let maximumBlockError: Double
  let changedBlockRatio: Double

  static func compare(
    reference: PetVisualFingerprint,
    candidate: PetVisualFingerprint
  ) -> PetVisualFingerprintDifference {
    let dimensionsMatch =
      reference.pixelsWide == candidate.pixelsWide
      && reference.pixelsHigh == candidate.pixelsHigh
    let referenceBytes = [UInt8](reference.signature)
    let candidateBytes = [UInt8](candidate.signature)
    guard dimensionsMatch,
      referenceBytes.count == PetVisualFingerprint.signatureByteCount,
      candidateBytes.count == referenceBytes.count
    else {
      return PetVisualFingerprintDifference(
        dimensionsMatch: false,
        meanAbsoluteError: 1,
        maximumBlockError: 1,
        changedBlockRatio: 1
      )
    }

    var totalError = 0.0
    var maximumBlockError = 0.0
    var changedBlocks = 0
    let blockCount = referenceBytes.count / 3
    for block in 0..<blockCount {
      let offset = block * 3
      let channelErrors = (0..<3).map { channel in
        abs(
          Double(referenceBytes[offset + channel])
            - Double(candidateBytes[offset + channel])
        ) / 255
      }
      let blockError = channelErrors.reduce(0, +) / 3
      totalError += channelErrors.reduce(0, +)
      maximumBlockError = max(maximumBlockError, blockError)
      if blockError > PetVisualBaselinePolicy.changedBlockThreshold {
        changedBlocks += 1
      }
    }

    return PetVisualFingerprintDifference(
      dimensionsMatch: true,
      meanAbsoluteError: totalError / Double(referenceBytes.count),
      maximumBlockError: maximumBlockError,
      changedBlockRatio: Double(changedBlocks) / Double(blockCount)
    )
  }
}

enum PetVisualBaselinePolicy {
  static let maximumMeanAbsoluteError = 0.025
  static let maximumBlockError = 0.30
  static let maximumChangedBlockRatio = 0.12
  static let changedBlockThreshold = 0.08

  static func accepts(_ difference: PetVisualFingerprintDifference) -> Bool {
    difference.dimensionsMatch
      && difference.meanAbsoluteError <= maximumMeanAbsoluteError
      && difference.maximumBlockError <= maximumBlockError
      && difference.changedBlockRatio <= maximumChangedBlockRatio
  }
}

struct PetVisualBaselineRecord: Codable, Equatable {
  let artifactName: String
  let fingerprint: PetVisualFingerprint
}

struct PetVisualBaselineManifest: Codable, Equatable {
  static let formatVersion = 1
  static let defaultURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("VisualBaselines", isDirectory: true)
    .appendingPathComponent(
      "deskpet-visual-fingerprints.json",
      isDirectory: false
    )

  let version: Int
  let gridColumns: Int
  let gridRows: Int
  let records: [PetVisualBaselineRecord]

  init(records: [PetVisualBaselineRecord]) {
    version = Self.formatVersion
    gridColumns = PetVisualFingerprint.gridColumns
    gridRows = PetVisualFingerprint.gridRows
    self.records = records.sorted { $0.artifactName < $1.artifactName }
  }

  static func decode(_ data: Data) throws -> PetVisualBaselineManifest {
    let decoded = try JSONDecoder().decode(PetVisualBaselineManifest.self, from: data)
    guard decoded.version == formatVersion,
      decoded.gridColumns == PetVisualFingerprint.gridColumns,
      decoded.gridRows == PetVisualFingerprint.gridRows,
      decoded.records.allSatisfy({
        $0.fingerprint.signature.count == PetVisualFingerprint.signatureByteCount
      }),
      Set(decoded.records.map(\.artifactName)).count == decoded.records.count
    else {
      throw PetVisualBaselineError.invalidManifest
    }
    return PetVisualBaselineManifest(records: decoded.records)
  }

  static func load(from url: URL) throws -> PetVisualBaselineManifest {
    try decode(Data(contentsOf: url))
  }

  func encoded() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(self)
    data.append(0x0A)
    return data
  }

  func write(to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try encoded().write(to: url, options: .atomic)
  }
}

enum PetVisualBaselineVerifier {
  @MainActor
  static func makeCurrentManifest() throws -> PetVisualBaselineManifest {
    var records: [PetVisualBaselineRecord] = []
    records.reserveCapacity(PetVisualSnapshotCase.standardMatrix.count)
    for snapshot in PetVisualSnapshotCase.standardMatrix {
      let data = try PetVisualSnapshotRenderer.pngData(for: snapshot)
      records.append(
        PetVisualBaselineRecord(
          artifactName: snapshot.artifactName,
          fingerprint: try PetVisualFingerprint.make(pngData: data)
        ))
    }
    return PetVisualBaselineManifest(records: records)
  }

  @MainActor
  static func verify(
    manifest: PetVisualBaselineManifest,
    snapshots: [PetVisualSnapshotCase] = PetVisualSnapshotCase.standardMatrix
  ) throws -> [String] {
    let expectedNames = Set(snapshots.map(\.artifactName))
    let baselineNames = Set(manifest.records.map(\.artifactName))
    var failures: [String] = []
    for missing in expectedNames.subtracting(baselineNames).sorted() {
      failures.append("Missing baseline: \(missing)")
    }
    for unexpected in baselineNames.subtracting(expectedNames).sorted() {
      failures.append("Unexpected baseline: \(unexpected)")
    }

    let records = Dictionary(
      uniqueKeysWithValues: manifest.records.map {
        ($0.artifactName, $0.fingerprint)
      }
    )
    for snapshot in snapshots {
      guard let reference = records[snapshot.artifactName] else { continue }
      let data = try PetVisualSnapshotRenderer.pngData(for: snapshot)
      let candidate = try PetVisualFingerprint.make(pngData: data)
      let difference = PetVisualFingerprintDifference.compare(
        reference: reference,
        candidate: candidate
      )
      guard !PetVisualBaselinePolicy.accepts(difference) else { continue }
      failures.append(
        String(
          format: "%@ mean=%.4f max=%.4f changed=%.3f",
          snapshot.artifactName,
          difference.meanAbsoluteError,
          difference.maximumBlockError,
          difference.changedBlockRatio
        ))
    }
    return failures
  }
}

enum PetVisualBaselineError: Error, Equatable {
  case invalidPNG
  case unreadablePixel
  case invalidManifest
}
