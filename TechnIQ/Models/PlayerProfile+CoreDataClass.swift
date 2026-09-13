import Foundation
import CoreData

@objc(PlayerProfile)
public class PlayerProfile: NSManagedObject {

    /// The weekdays the player trains, as chosen at onboarding or in the training profile.
    /// Falls back to the onboarding frequency mapping's default (Mon / Wed / Fri) when unset.
    var trainingDayList: [DayOfWeek] {
        get {
            let raw = Set((trainingDays ?? "").split(separator: ",").compactMap { DayOfWeek(rawValue: String($0).trimmingCharacters(in: .whitespaces)) })
            return raw.isEmpty ? [.monday, .wednesday, .friday] : raw.sorted { $0.sortOrder < $1.sortOrder }
        }
        set {
            let ordered = Set(newValue).sorted { $0.sortOrder < $1.sortOrder }
            trainingDays = ordered.isEmpty ? nil : ordered.map(\.rawValue).joined(separator: ",")
        }
    }
}
