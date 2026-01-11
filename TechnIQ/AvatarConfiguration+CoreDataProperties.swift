import Foundation
import CoreData

extension AvatarConfiguration {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AvatarConfiguration> {
        return NSFetchRequest<AvatarConfiguration>(entityName: "AvatarConfiguration")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var skinTone: String?
    @NSManaged public var hairStyle: String?
    @NSManaged public var hairColor: String?
    @NSManaged public var faceStyle: String?
    @NSManaged public var jerseyId: String?
    @NSManaged public var shortsId: String?
    @NSManaged public var cleatsId: String?
    @NSManaged public var accessoryIds: NSArray?
    @NSManaged public var lastModified: Date?
    @NSManaged public var player: Player?

}

extension AvatarConfiguration: Identifiable {

}
