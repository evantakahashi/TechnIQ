import Foundation
import CoreData

extension Benchmark {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Benchmark> {
        return NSFetchRequest<Benchmark>(entityName: "Benchmark")
    }

    @NSManaged public var id: UUID?
    /// `BenchmarkType` raw value.
    @NSManaged public var type: String?
    @NSManaged public var value: Int32
    @NSManaged public var date: Date?
    /// Counted by the camera (true) or typed in by the player (false).
    @NSManaged public var cameraVerified: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var player: Player?

}

extension Benchmark: Identifiable {

}
