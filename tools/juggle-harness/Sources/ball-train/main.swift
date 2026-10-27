// Trains the ball detector with Create ML (Apple's own YOLOv2-style detector; no third-party licence) from
// a folder of JPEGs + annotations.json (Create ML format: written by `juggle-harness --labels-out`, checked in
// tools/ball-labeler). Output is a Core ML model the app loads in place of the placeholder YOLO11n.
//
//   swift run -c release --package-path tools/juggle-harness ball-train <labels-dir> <out.mlmodel> \
//       [--annotations checked.json] [--iterations 3000] [--grid 13]
//
// --annotations: train on that file's frames only (the labeler's checked set) instead of annotations.json.

import CreateML
import Foundation

var args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 2 else {
    print("usage: ball-train <labels-dir> <out.mlmodel> [--annotations checked.json] [--iterations 3000] [--grid 13]")
    exit(2)
}
let labelsDir = URL(fileURLWithPath: args.removeFirst())
let output = URL(fileURLWithPath: args.removeFirst())
var iterations = 3000
var grid = 13
var annotationFile: URL?
while let flag = args.first {
    args.removeFirst()
    let raw = args.isEmpty ? nil : args.removeFirst()
    let value = raw.flatMap { Int($0) }
    switch flag {
    case "--annotations": annotationFile = raw.map { URL(fileURLWithPath: $0, relativeTo: labelsDir) }
    case "--iterations": iterations = value ?? iterations
    case "--grid": grid = value ?? grid
    default: print("unknown flag \(flag)"); exit(2)
    }
}

let parameters = MLObjectDetector.ModelParameters(
    validation: .split(strategy: .automatic),
    batchSize: 32,
    maxIterations: iterations,
    // Finer grid = more cells for a small ball (input side = 32 × grid).
    gridSize: CGSize(width: grid, height: grid),
    algorithm: .darknetYolo
)

let start = Date()
let data: MLObjectDetector.DataSource = annotationFile.map { .directoryWithImages(at: labelsDir, annotationFile: $0) }
    ?? .directoryWithImagesAndJsonAnnotation(at: labelsDir)
let detector = try MLObjectDetector(trainingData: data,
                                    parameters: parameters,
                                    annotationType: .boundingBox(units: .pixel, origin: .topLeft, anchor: .center))
print(String(format: "trained in %.0f s", Date().timeIntervalSince(start)))
print("training:   \(detector.trainingMetrics)")
print("validation: \(detector.validationMetrics)")
try detector.write(to: output, metadata: MLModelMetadata(author: "TechnIQ", shortDescription: "Soccer ball detector", version: "1"))
print("wrote \(output.path)")
