//
//  TechnIQApp.swift
//  TechnIQ
//
//  Created by Evan Takahashi on 6/30/25.
//

import SwiftUI
import CoreData

@main
struct TechnIQApp: App {
    let coreDataManager = CoreDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataManager.context)
                .environmentObject(coreDataManager)
                .onAppear {
                    setupDefaultData()
                }
        }
    }
    
    private func setupDefaultData() {
        let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        do {
            let count = try coreDataManager.context.count(for: request)
            if count == 0 {
                coreDataManager.createDefaultExercises()
            }
        } catch {
            print("Error checking exercises: \(error)")
        }
    }
}
