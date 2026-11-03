// Replays a device session's frames.jsonl (DEBUG CameraDebugDump, Documents/CameraDebug) through a drill
// counter, so counting changes can be checked against a real run without re-filming.
//
//   swift run -c release --package-path tools/juggle-harness replay <frames.jsonl> [--drill juggling]

import Foundation
@testable import JuggleCore

let args = Array(CommandLine.arguments.dropFirst())
guard let path = args.first else {
    print("usage: replay <frames.jsonl> [--drill juggling|weakFootJuggling|alternatingJuggling|toeTaps|wallPasses]")
    exit(2)
}
let drillName = args.firstIndex(of: "--drill").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? "juggling"
guard let drill = CameraDrill(rawValue: drillName), let counter = drill.makeCounter() else {
    print("unknown drill \(drillName)"); exit(2)
}
guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { print("can't read \(path)"); exit(2) }
let decoder = JSONDecoder()
let frames = text.split(whereSeparator: \.isNewline).compactMap { try? decoder.decode(DrillFrame.self, from: Data($0.utf8)) }
guard let start = frames.first?.time else { print("no frames"); exit(1) }

var runs: [Int] = []
func show(_ events: [DrillEvent]) {
    for event in events {
        switch event {
        case let .touch(count, part, time, side):
            print(String(format: "  %6.2fs  touch %2d  %@%@", time - start, count, part.rawValue, side.map { " (\($0.rawValue))" } ?? ""))
        case let .runEnded(count, reason, time):
            print(String(format: "  %6.2fs  run ended at %d (%@)", time - start, count, reason.rawValue))
            runs.append(count)
        }
    }
}
for frame in frames { show(counter.process(frame)) }
show(counter.finish(at: frames.last?.time ?? start))
print("\(frames.count) frames, runs: \(runs)")
