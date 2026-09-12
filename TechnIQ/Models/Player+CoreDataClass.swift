import Foundation
import CoreData

@objc(Player)
public class Player: NSManagedObject {

    /// Shirt number when set (1–99); nil when the player hasn't chosen one.
    public var kitNumberValue: Int? {
        get { kitNumber > 0 ? Int(kitNumber) : nil }
        set { kitNumber = Int16(clamping: newValue ?? 0) }
    }

    /// Skills pinned to the top of the Train screen, in pin order.
    var pinnedSkillList: [WeaknessCategory] {
        get { (pinnedSkills ?? "").split(separator: ",").compactMap { WeaknessCategory(rawValue: String($0)) } }
        set { pinnedSkills = newValue.isEmpty ? nil : newValue.map(\.rawValue).joined(separator: ",") }
    }
}