import Foundation

/// Fills short gaps where the ball detector misses (motion blur, the ball against a leg) with an
/// object tracker seeded from the last detection.
///
/// Platform-agnostic: the caller supplies `seed` (start tracking this box, on this frame) and
/// `track` (where the tracker thinks the ball is now). Gaps are capped short so a tracker that has
/// drifted onto a foot or the background can't invent touches.
final class BallGapFiller {
    struct Config {
        /// Longest stretch (seconds) after a detection that the tracker may fill.
        var maxGap = 0.3
        /// Tracker confidence below this means it has lost the ball.
        var minConfidence = 0.5
        /// Furthest (height units) the ball can plausibly move between consecutive frames.
        var maxJump = 0.15
    }

    let config: Config
    private var lastDetection: Double?
    private var lastBall: BallSighting?
    /// The tracker lost the ball in this gap; wait for the detector.
    private var lost = false

    init(config: Config = Config()) {
        self.config = config
    }

    /// The ball for this frame: the detection when there is one (re-seeding the tracker on it),
    /// else the tracker's guess while the gap is short and the guess is believable.
    func ball(detected: BallSighting?, at time: Double,
              seed: (BallSighting) -> Void, track: () -> BallSighting?) -> BallSighting? {
        if let detected {
            seed(detected)
            lastDetection = time
            lastBall = detected
            lost = false
            return detected
        }
        guard !lost, let lastDetection, time - lastDetection <= config.maxGap, let lastBall else { return nil }
        guard let tracked = track(), tracked.confidence >= config.minConfidence,
              tracked.center.distance(to: lastBall.center) < config.maxJump else {
            lost = true
            return nil
        }
        // Tracker boxes swell and shrink; the detector's size is the better radius.
        let filled = BallSighting(center: tracked.center, radius: lastBall.radius, confidence: tracked.confidence)
        self.lastBall = filled
        return filled
    }
}
