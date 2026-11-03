import Foundation

/// Central feature gates. Default OFF for gated features; flip via launch argument (UI tests / dev)
/// or UserDefaults (remote-config hook later).
enum FeatureFlags {
    /// YouTube video-drill import + its library filters. Hidden for v1.
    static var youtubeDrills: Bool { isOn("-TQYouTubeDrills", key: "ff.youtubeDrills") }

    /// Community tab (Feed / Drills / Leaderboard) and every way into it (share-to-community,
    /// share plan with community). Off until moderation + seeded content are ready.
    static var community: Bool { isOn("-TQCommunity", key: "ff.community") }

    /// Camera drills that have no counter yet (shown as "soon"). Off: they're hidden entirely.
    static var soonCameraDrills: Bool { isOn("-TQSoonCameraDrills", key: "ff.soonCameraDrills") }

    private static func isOn(_ launchArgument: String, key: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument) || UserDefaults.standard.bool(forKey: key)
    }
}
