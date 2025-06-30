import Foundation
import CoreData

extension Player {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Player> {
        return NSFetchRequest<Player>(entityName: "Player")
    }

    @NSManaged public var age: Int16
    @NSManaged public var createdAt: Date?
    @NSManaged public var dominantFoot: String?
    @NSManaged public var height: Double
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var playingStyle: String?
    @NSManaged public var position: String?
    @NSManaged public var weight: Double
    @NSManaged public var sessions: NSSet?
    @NSManaged public var stats: NSSet?

}

// MARK: Generated accessors for sessions
extension Player {

    @objc(addSessionsObject:)
    @NSManaged public func addToSessions(_ value: TrainingSession)

    @objc(removeSessionsObject:)
    @NSManaged public func removeFromSessions(_ value: TrainingSession)

    @objc(addSessions:)
    @NSManaged public func addToSessions(_ values: NSSet)

    @objc(removeSessions:)
    @NSManaged public func removeFromSessions(_ values: NSSet)

}

// MARK: Generated accessors for stats
extension Player {

    @objc(addStatsObject:)
    @NSManaged public func addToStats(_ value: PlayerStats)

    @objc(removeStatsObject:)
    @NSManaged public func removeFromStats(_ value: PlayerStats)

    @objc(addStats:)
    @NSManaged public func addToStats(_ values: NSSet)

    @objc(removeStats:)
    @NSManaged public func removeFromStats(_ values: NSSet)

}

extension Player : Identifiable {

}