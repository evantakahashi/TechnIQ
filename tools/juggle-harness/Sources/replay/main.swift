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
let recorder = RunRecorder()
var allStats: [RunStats] = []
func showStats(_ stats: [RunStats]) {
    for s in stats where s.count >= 3 {
        let metres = { (v: Double?) in v.map { String(format: "%.2f m", $0) } ?? "-" }
        print("    run of \(s.count): L \(s.leftFoot) / R \(s.rightFoot), hidden \(s.ambiguous), "
              + "height L \(metres(s.apexLeft)) R \(metres(s.apexRight)), "
              + "\(s.touchesPerMinute.map { String(format: "%.0f/min", $0) } ?? "-"), drift \(metres(s.drift)) | \(s.endLine)")
        for line in s.insights { print("      - \(line)") }
    }
    allStats += stats
}
for frame in frames {
    let events = counter.process(frame)
    show(events)
    showStats(recorder.record(frame, events: events))
}
let last = frames.last ?? frames[0]
let closing = counter.finish(at: last.time)
show(closing)
showStats(recorder.record(last, events: closing))
print("\(frames.count) frames, runs: \(runs)")
if let line = RunStats.sessionLine(allStats) { print(line) }
