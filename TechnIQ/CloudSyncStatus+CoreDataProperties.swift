import Foundation
import CoreData

extension CloudSyncStatus {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CloudSyncStatus> {
        return NSFetchRequest<CloudSyncStatus>(entityName: "CloudSyncStatus")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var playerID: String?
    @NSManaged public var entityType: String?
    @NSManaged public var lastSyncDate: Date?
    @NSManaged public var syncStatus: String?
    @NSManaged public var pendingChanges: Bool
    @NSManaged public var errorMessage: String?
    @NSManaged public var retryCount: Int16
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?

}

extension CloudSyncStatus : Identifiable {

}