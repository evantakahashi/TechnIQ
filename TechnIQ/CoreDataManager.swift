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
    
    // MARK: - YouTube Integration
    
    func createExerciseFromYouTubeVideo(
        videoId: String,
        title: String,
        description: String,
        thumbnailURL: String,
        duration: Int,
        channelTitle: String,
        category: String = "Technical",
        difficulty: Int = 2,
        targetSkills: [String] = []
    ) -> Exercise {
        let exercise = Exercise(context: context)
        exercise.id = UUID()
        exercise.name = title
        exercise.category = category
        exercise.difficulty = Int16(difficulty)
        exercise.exerciseDescription = description
        exercise.instructions = "Watch this YouTube video to learn the technique, then practice in real life."
        exercise.targetSkills = targetSkills
        
        // Store YouTube info in the description for now (until Core Data fields are available)
        exercise.exerciseDescription = "\(description)\n\n🎥 YouTube Video\nChannel: \(channelTitle)\nVideo ID: \(videoId)"
        exercise.instructions = "1. Watch the YouTube video at: https://youtube.com/watch?v=\(videoId)\n2. Practice the technique shown\n3. Focus on the key points demonstrated"
        
        save()
        return exercise
    }
    
    func loadYouTubeDrillsFromAPI(category: String? = nil, maxResults: Int = 10) async {
        let apiKey = YouTubeConfig.apiKey
        
        Task {
            do {
                let searchQuery = category ?? "soccer training drills"
                let videos = try await performYouTubeSearch(query: searchQuery, apiKey: apiKey, maxResults: maxResults)
                
                await MainActor.run {
                    for video in videos {
                        // Check if we already have this video
                        let existingExercise = findExerciseByYouTubeID(video.videoId)
                        if existingExercise == nil {
                            let skills = analyzeVideoForSkills(title: video.title, description: "")
                            let difficulty = analyzeVideoDifficulty(title: video.title)
                            
                            _ = createExerciseFromYouTubeVideo(
                                videoId: video.videoId,
                                title: video.title,
                                description: video.title,
                                thumbnailURL: "https://img.youtube.com/vi/\(video.videoId)/medium.jpg",
                                duration: 300, // Default 5 minutes
                                channelTitle: video.channel,
                                category: category ?? "Technical",
                                difficulty: difficulty,
                                targetSkills: skills
                            )
                        }
                    }
                }
            } catch {
                print("Error loading YouTube drills: \(error)")
            }
        }
    }
    
    private func findExerciseByYouTubeID(_ videoId: String) -> Exercise? {
        let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        request.predicate = NSPredicate(format: "exerciseDescription CONTAINS %@", "Video ID: \(videoId)")
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            return results.first
        } catch {
            print("Error finding exercise by YouTube ID: \(error)")
            return nil
        }
    }
    
    private func analyzeVideoForSkills(title: String, description: String) -> [String] {
        let content = (title + " " + description).lowercased()
        var skills: [String] = []
        
        if content.contains("dribbling") || content.contains("dribble") {
            skills.append("Dribbling")
        }
        if content.contains("passing") || content.contains("pass") {
            skills.append("Passing")
        }
        if content.contains("shooting") || content.contains("shot") {
            skills.append("Shooting")
        }
        if content.contains("control") || content.contains("touch") {
            skills.append("Ball Control")
        }
        if content.contains("speed") || content.contains("sprint") {
            skills.append("Speed")
        }
        if content.contains("agility") || content.contains("footwork") {
            skills.append("Agility")
        }
        
        return skills.isEmpty ? ["Ball Control"] : skills
    }
    
    private func analyzeVideoDifficulty(title: String) -> Int {
        let content = title.lowercased()
        
        if content.contains("advanced") || content.contains("professional") || content.contains("expert") {
            return 3
        } else if content.contains("intermediate") || content.contains("complex") {
            return 2
        } else {
            return 1
        }
    }
    
    private func performYouTubeSearch(query: String, apiKey: String, maxResults: Int) async throws -> [YouTubeTestVideo] {
        let urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=\(maxResults)&q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&type=video&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for YouTube search")
            return []
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response")
                return []
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                print("❌ HTTP error: \(httpResponse.statusCode)")
                return []
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else {
                print("❌ Failed to parse YouTube response")
                return []
            }
            
            return items.compactMap { item in
                guard let id = item["id"] as? [String: Any],
                      let videoId = id["videoId"] as? String,
                      let snippet = item["snippet"] as? [String: Any],
                      let title = snippet["title"] as? String,
                      let channelTitle = snippet["channelTitle"] as? String else {
                    return nil
                }
                
                return YouTubeTestVideo(
                    videoId: videoId,
                    title: title,
                    channel: channelTitle,
                    duration: "N/A"
                )
            }
        } catch {
            print("❌ Network error: \(error)")
            return []
        }
    }
}