import Foundation
import CoreData

extension OwnedAvatarItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<OwnedAvatarItem> {
        return NSFetchRequest<OwnedAvatarItem>(entityName: "OwnedAvatarItem")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var itemId: String?
    @NSManaged public var purchasedAt: Date?
    @NSManaged public var equippedSlot: String?
    @NSManaged public var player: Player?

}

extension OwnedAvatarItem: Identifiable {

}
