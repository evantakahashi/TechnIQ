import CoreData
import Foundation

class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DataModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data error: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func save() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Save error: \(error.localizedDescription)")
            }
        }
    }
}

extension CoreDataManager {
    func createDefaultExercises() {
        let exercises = [
            ("Ball Control", "Technical", 1, "Basic ball touches and control", ["Ball Control", "First Touch"]),
            ("Juggling", "Technical", 2, "Keep the ball in the air using different body parts", ["Ball Control", "Coordination"]),
            ("Dribbling Cones", "Technical", 2, "Dribble through a series of cones", ["Dribbling", "Agility"]),
            ("Shooting Practice", "Technical", 3, "Practice shooting accuracy and power", ["Shooting", "Accuracy"]),
            ("Passing Accuracy", "Technical", 2, "Short and long passing practice", ["Passing", "Vision"]),
            ("Sprint Training", "Physical", 2, "Short distance sprint intervals", ["Speed", "Acceleration"]),
            ("Agility Ladder", "Physical", 2, "Footwork and agility drills", ["Agility", "Coordination"]),
            ("Endurance Run", "Physical", 1, "Continuous running for stamina", ["Endurance", "Fitness"]),
            ("1v1 Practice", "Tactical", 3, "One-on-one attacking and defending", ["Defending", "Attacking"]),
            ("Small-Sided Games", "Tactical", 3, "3v3 or 4v4 mini games", ["Teamwork", "Decision Making"])
        ]
        
        for (name, category, difficulty, description, skills) in exercises {
            let exercise = Exercise(context: context)
            exercise.id = UUID()
            exercise.name = name
            exercise.category = category
            exercise.difficulty = Int16(difficulty)
            exercise.exerciseDescription = description
            exercise.targetSkills = skills
            exercise.instructions = "Follow standard \(name.lowercased()) protocol"
        }
        
        save()
    }
}