import Foundation
import CoreData

// MARK: - AvatarService Protocol

@MainActor
protocol AvatarServiceProtocol: AnyObject {
    var currentAvatarState: AvatarState { get }
    var ownedItemIds: Set<String> { get }

    func loadCurrentAvatar()
    func getAvatarState(context: NSManagedObjectContext?) -> AvatarState
    @discardableResult func saveAvatarState(_ avatarState: AvatarState, context: NSManagedObjectContext?) -> Bool
    func updateSlot(_ slot: AvatarSlot, value: String) -> Bool
    func loadOwnedItems()
    func ownsItem(_ itemId: String) -> Bool
    @discardableResult func addItemToInventory(_ itemId: String, context: NSManagedObjectContext?) -> Bool
    func ownedItems(for slot: AvatarSlot) -> [String]
}
