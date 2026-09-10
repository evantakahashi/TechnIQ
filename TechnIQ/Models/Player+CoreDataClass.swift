import Foundation
import CoreData

@objc(Player)
public class Player: NSManagedObject {

    /// Shirt number when set (1–99); nil when the player hasn't chosen one.
    public var kitNumberValue: Int? {
        get { kitNumber > 0 ? Int(kitNumber) : nil }
        set { kitNumber = Int16(clamping: newValue ?? 0) }
    }
}