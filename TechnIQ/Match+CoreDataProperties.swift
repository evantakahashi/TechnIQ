import Foundation
import CoreData

extension Match {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Match> {
        return NSFetchRequest<Match>(entityName: "Match")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var opponent: String?
    @NSManaged public var competition: String?
    @NSManaged public var minutesPlayed: Int16
    @NSManaged public var goals: Int16
    @NSManaged public var assists: Int16
    @NSManaged public var positionPlayed: String?
    @NSManaged public var isHomeGame: Bool
    @NSManaged public var result: String?
    @NSManaged public var notes: String?
    @NSManaged public var rating: Int16
    @NSManaged public var xpEarned: Int32
    @NSManaged public var strengths: String?
    @NSManaged public var weaknesses: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var player: Player?
    @NSManaged public var season: Season?

}

extension Match : Identifiable {

}
