import Foundation

/// Picks the juggled ball out of each frame's detector candidates.
///
/// Detectors also fire on round scenery (plant pots, lamps, a spare ball by the fence). A juggled ball
/// never sits still for long, so anything that stays put for `staticAfter` seconds is treated as scenery
/// until it moves. Among the rest, the candidate nearest last frame's ball wins, else the most confident.
final class BallTracker {
    struct Config {
        /// Seconds a detection may stay put before it's scenery.
        var staticAfter = 1.0
        /// How far (height units) a detection may wander and still be "the same spot".
        var spotTolerance = 0.015
        /// Share of frames since a spot appeared that must hit it: scenery shows up in most frames
        /// (the detector flickers, ~50% on a pot), while a juggled ball only passes through on the way up and down (~15%).
        var staticPresence = 0.3
        /// A spot not seen for this long is forgotten.
        var spotMemory = 1.5
        /// Once a spot is scenery it stays scenery this long after its last sighting (the detector can
        /// lose a pot for seconds at a time).
        var sceneryMemory = 10.0
        /// Furthest the ball can plausibly move between consecutive picks.
        var maxJump = 0.15
    }

    private struct Spot {
        var center: DrillPoint
        var since: Double
        var lastSeen: Double
        var frames = 0
        var hits = 0
        var isScenery = false
    }

    let config: Config
    private var spots: [Spot] = []
    private var lastBall: DrillPoint?

    init(config: Config = Config()) {
        self.config = config
    }

    func pick(_ candidates: [BallSighting], at time: Double) -> BallSighting? {
        spots.removeAll { time - $0.lastSeen > ($0.isScenery ? config.sceneryMemory : config.spotMemory) }
        for i in spots.indices { spots[i].frames += 1 }
        let moving = candidates.filter { !isStatic($0.center, at: time) }

        let pick: BallSighting?
        if let lastBall,
           let nearest = moving.min(by: { $0.center.distance(to: lastBall) < $1.center.distance(to: lastBall) }),
           nearest.center.distance(to: lastBall) < config.maxJump {
            pick = nearest
        } else {
            pick = moving.max { $0.confidence < $1.confidence }
        }
        lastBall = pick?.center
        return pick
    }

    /// Records the sighting against its spot and says whether it has stayed put too long.
    private func isStatic(_ point: DrillPoint, at time: Double) -> Bool {
        guard let i = spots.firstIndex(where: { $0.center.distance(to: point) <= config.spotTolerance }) else {
            spots.append(Spot(center: point, since: time, lastSeen: time, frames: 1, hits: 1))
            return false
        }
        spots[i].lastSeen = time
        spots[i].hits += 1
        let spot = spots[i]
        if !spot.isScenery, time - spot.since >= config.staticAfter,
           Double(spot.hits) >= config.staticPresence * Double(spot.frames) {
            spots[i].isScenery = true
        }
        return spots[i].isScenery
    }
}
