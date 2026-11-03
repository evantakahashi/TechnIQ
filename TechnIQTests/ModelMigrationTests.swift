import CoreData
import XCTest
@testable import TechnIQ

/// A store written by every shipped model version must open under the current model with
/// lightweight (inferred) migration. Add a case here whenever a model version is added.
final class ModelMigrationTests: XCTestCase {

    private var storeURL: URL!

    override func setUp() {
        super.setUp()
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-\(UUID().uuidString).sqlite")
    }

    override func tearDown() {
        let dir = storeURL.deletingLastPathComponent()
        let base = storeURL.lastPathComponent
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(base + suffix))
        }
        super.tearDown()
    }

    private func model(named name: String) throws -> NSManagedObjectModel {
        let bundle = Bundle(for: CoreDataManager.self)
        let momd = try XCTUnwrap(bundle.url(forResource: "DataModel", withExtension: "momd"))
        let url = momd.appendingPathComponent("\(name).mom")
        return try XCTUnwrap(NSManagedObjectModel(contentsOf: url), "missing model version \(name)")
    }

    func test_currentVersion_isDataModel2() throws {
        let bundle = Bundle(for: CoreDataManager.self)
        let momd = try XCTUnwrap(bundle.url(forResource: "DataModel", withExtension: "momd"))
        let info = try XCTUnwrap(NSDictionary(contentsOf: momd.appendingPathComponent("VersionInfo.plist")))
        XCTAssertEqual(info["NSManagedObjectModel_CurrentVersionName"] as? String, "DataModel 2")
    }

    func test_v1Store_migratesToCurrentModel_keepingRows() throws {
        // Write a v1 (shipped v1.0) store with a player, a drill and a session.
        let v1 = try model(named: "DataModel")
        let v1Coordinator = NSPersistentStoreCoordinator(managedObjectModel: v1)
        _ = try v1Coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
        let v1Context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        v1Context.persistentStoreCoordinator = v1Coordinator

        let player = NSEntityDescription.insertNewObject(forEntityName: "Player", into: v1Context)
        player.setValue(UUID(), forKey: "id")
        player.setValue("uid-migration", forKey: "firebaseUID")
        player.setValue("Migrator", forKey: "name")
        player.setValue(Int64(420), forKey: "totalXP")
        let exercise = NSEntityDescription.insertNewObject(forEntityName: "Exercise", into: v1Context)
        exercise.setValue(UUID(), forKey: "id")
        exercise.setValue("Juggling", forKey: "name")
        exercise.setValue(player, forKey: "player")
        let session = NSEntityDescription.insertNewObject(forEntityName: "TrainingSession", into: v1Context)
        session.setValue(UUID(), forKey: "id")
        session.setValue(Double(25), forKey: "duration")
        session.setValue(player, forKey: "player")
        try v1Context.save()
        for store in v1Coordinator.persistentStores { try v1Coordinator.remove(store) }

        // Reopen with the app's current model, the same way CoreDataManager does.
        let current = CoreDataManager.shared.persistentContainer.managedObjectModel
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: current)
        let options: [String: Any] = [NSMigratePersistentStoresAutomaticallyOption: true,
                                      NSInferMappingModelAutomaticallyOption: true]
        XCTAssertNoThrow(try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
                                                            at: storeURL, options: options))
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        let players = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Player"))
        XCTAssertEqual(players.count, 1)
        XCTAssertEqual(players.first?.value(forKey: "totalXP") as? Int64, 420)
        let exercises = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Exercise"))
        XCTAssertEqual(exercises.first?.value(forKey: "name") as? String, "Juggling")
        XCTAssertNil(exercises.first?.value(forKey: "cue"))
        let sessions = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "TrainingSession"))
        XCTAssertEqual(sessions.first?.value(forKey: "activeSeconds") as? Double, 0)
        XCTAssertNil(sessions.first?.value(forKey: "feel"))
        XCTAssertEqual(try context.count(for: NSFetchRequest<NSManagedObject>(entityName: "Benchmark")), 0)
    }

    func test_v1StoreWithCoinsAndShopItems_migratesToCurrentModel() throws {
        // v1.0 had coins and an OwnedAvatarItem entity; the current model drops both.
        let v1 = try model(named: "DataModel")
        XCTAssertNotNil(v1.entitiesByName["OwnedAvatarItem"])
        let v1Coordinator = NSPersistentStoreCoordinator(managedObjectModel: v1)
        _ = try v1Coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
        let v1Context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        v1Context.persistentStoreCoordinator = v1Coordinator

        let player = NSEntityDescription.insertNewObject(forEntityName: "Player", into: v1Context)
        player.setValue(UUID(), forKey: "id")
        player.setValue("uid-coins", forKey: "firebaseUID")
        player.setValue(Int64(640), forKey: "coins")
        player.setValue(Int64(1_200), forKey: "totalXP")
        let item = NSEntityDescription.insertNewObject(forEntityName: "OwnedAvatarItem", into: v1Context)
        item.setValue(UUID(), forKey: "id")
        item.setValue("jersey_royal_blue", forKey: "itemId")
        item.setValue(Date(), forKey: "purchasedAt")
        item.setValue(player, forKey: "player")
        try v1Context.save()
        for store in v1Coordinator.persistentStores { try v1Coordinator.remove(store) }

        let current = CoreDataManager.shared.persistentContainer.managedObjectModel
        XCTAssertNil(current.entitiesByName["OwnedAvatarItem"])
        XCTAssertNil(current.entitiesByName["Player"]?.attributesByName["coins"])
        XCTAssertNil(current.entitiesByName["Player"]?.attributesByName["totalCoinsEarned"])
        XCTAssertNil(current.entitiesByName["Player"]?.relationshipsByName["ownedAvatarItems"])
        XCTAssertNil(current.entitiesByName["CameraRun"]?.attributesByName["coinsEarned"])

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: current)
        let options: [String: Any] = [NSMigratePersistentStoresAutomaticallyOption: true,
                                      NSInferMappingModelAutomaticallyOption: true]
        XCTAssertNoThrow(try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
                                                            at: storeURL, options: options))
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        let players = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Player"))
        XCTAssertEqual(players.count, 1)
        XCTAssertEqual(players.first?.value(forKey: "firebaseUID") as? String, "uid-coins")
        XCTAssertEqual(players.first?.value(forKey: "totalXP") as? Int64, 1_200)
    }
}
