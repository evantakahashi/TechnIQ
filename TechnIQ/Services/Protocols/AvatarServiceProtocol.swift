import Foundation
import CoreData

// MARK: - AvatarService Protocol

@MainActor
protocol AvatarServiceProtocol: AnyObject {
    var currentAvatarState: AvatarState { get }

    func loadCurrentAvatar()
    func getAvatarState(context: NSManagedObjectContext?) -> AvatarState
    @discardableResult func saveAvatarState(_ avatarState: AvatarState, context: NSManagedObjectContext?) -> Bool
    func updateSlot(_ slot: AvatarSlot, value: String) -> Bool
}
