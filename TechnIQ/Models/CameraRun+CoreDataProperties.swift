import Foundation
import CoreData

extension CameraRun {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CameraRun> {
        return NSFetchRequest<CameraRun>(entityName: "CameraRun")
    }

    @NSManaged public var id: UUID?
    /// `CameraDrill` raw value.
    @NSManaged public var drill: String?
    @NSManaged public var count: Int32
    /// Seconds from first touch (or go) to run end.
    @NSManaged public var duration: Double
    @NSManaged public var isPersonalBest: Bool
    @NSManaged public var challengeId: String?
    /// Local highlight clip (Documents-relative), when one was kept.
    @NSManaged public var clipPath: String?
    /// `RunEndReason` raw value: why the run ended (ground, a rule call, …).
    @NSManaged public var endReason: String?
    /// `RunStats` as JSON: touches, splits, heights, tempo — for insights and trends.
    @NSManaged public var statsJSON: String?
    @NSManaged public var xpEarned: Int32
    @NSManaged public var coinsEarned: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var player: Player?

}

extension CameraRun: Identifiable {

}

extension CameraRun {
    /// The run's stats, decoded from `statsJSON` (nil for runs saved before stats existed).
    var stats: RunStats? {
        get { statsJSON.flatMap { try? JSONDecoder().decode(RunStats.self, from: Data($0.utf8)) } }
        set { statsJSON = newValue.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) } }
    }
}
