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
    @NSManaged public var xpEarned: Int32
    @NSManaged public var coinsEarned: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var player: Player?

}

extension CameraRun: Identifiable {

}
