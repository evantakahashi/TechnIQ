import Foundation
import CoreData
import Combine

/// Service for managing player avatar configuration. Every item is free.
@MainActor
final class AvatarService: ObservableObject, AvatarServiceProtocol {
    static let shared = AvatarService()

    // MARK: - Published Properties

    /// Current avatar state (for reactive UI updates)
    @Published private(set) var currentAvatarState: AvatarState = .default

    // MARK: - Private Properties

    private let coreDataManager = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadCurrentAvatar()
    }

    // MARK: - Avatar Configuration

    /// Load the current player's avatar configuration
    func loadCurrentAvatar() {
        let context = coreDataManager.context
        guard let player = coreDataManager.getCurrentPlayer() else {
            currentAvatarState = .default
            return
        }

        // Ensure avatar configuration exists
        if player.avatarConfiguration == nil {
            createDefaultAvatarConfiguration(for: player, context: context)
        }

        currentAvatarState = avatarState(from: player.avatarConfiguration)
    }

    /// Get avatar state for current player
    func getAvatarState(context: NSManagedObjectContext? = nil) -> AvatarState {
        guard let player = coreDataManager.getCurrentPlayer(),
              let config = player.avatarConfiguration else {
            return .default
        }
        return avatarState(from: config)
    }

    /// Save avatar configuration changes
    /// - Parameters:
    ///   - avatarState: The new avatar state to save
    ///   - context: Core Data context (uses main if not provided)
    /// - Returns: True if save was successful
    @discardableResult
    func saveAvatarState(_ avatarState: AvatarState, context: NSManagedObjectContext? = nil) -> Bool {
        let ctx = context ?? coreDataManager.context
        guard let player = coreDataManager.getCurrentPlayer() else {
            #if DEBUG
            print("[AvatarService] No player found to save avatar")
            #endif
            return false
        }

        // Create configuration if it doesn't exist
        let config: AvatarConfiguration
        if let existing = player.avatarConfiguration {
            config = existing
        } else {
            config = AvatarConfiguration(context: ctx)
            config.id = UUID()
            player.avatarConfiguration = config
        }

        // Update configuration with raw values
        config.skinTone = avatarState.skinTone.rawValue
        config.hairStyle = avatarState.hairStyle.rawValue
        config.hairColor = avatarState.hairColor.rawValue
        config.faceStyle = avatarState.faceStyle.rawValue
        config.jerseyId = avatarState.jerseyStyle.rawValue
        config.shortsId = avatarState.shortsStyle.rawValue
        config.socksId = avatarState.socksStyle.rawValue
        config.cleatsId = avatarState.cleatsStyle.rawValue
        config.lastModified = Date()
        config.updatedAt = Date()

        do {
            try ctx.save()

            currentAvatarState = avatarState

            Task { @MainActor in try? await CloudService.shared.syncAvatarConfiguration(config, for: player) }

            #if DEBUG
            print("[AvatarService] Avatar configuration saved successfully")
            #endif
            return true
        } catch {
            #if DEBUG
            print("[AvatarService] Failed to save avatar: \(error)")
            #endif
            ctx.rollback()
            return false
        }
    }

    /// Update a single avatar slot
    /// - Parameters:
    ///   - slot: The slot to update
    ///   - value: The new value for the slot (raw string value)
    @discardableResult
    func updateSlot(_ slot: AvatarSlot, value: String) -> Bool {
        var newState = currentAvatarState

        switch slot {
        case .skinTone:
            if let skinTone = SkinTone(rawValue: value) {
                newState.skinTone = skinTone
            }
        case .hairStyle:
            if let hairStyle = HairStyle(rawValue: value) {
                newState.hairStyle = hairStyle
            }
        case .hairColor:
            if let hairColor = HairColor(rawValue: value) {
                newState.hairColor = hairColor
            }
        case .faceStyle:
            if let faceStyle = FaceStyle(rawValue: value) {
                newState.faceStyle = faceStyle
            }
        case .jersey:
            if let jerseyStyle = JerseyStyle(rawValue: value) {
                newState.jerseyStyle = jerseyStyle
            }
        case .shorts:
            if let shortsStyle = ShortsStyle(rawValue: value) {
                newState.shortsStyle = shortsStyle
            }
        case .socks:
            if let socksStyle = SocksStyle(rawValue: value) {
                newState.socksStyle = socksStyle
            }
        case .cleats:
            if let cleatsStyle = CleatsStyle(rawValue: value) {
                newState.cleatsStyle = cleatsStyle
            }
        case .accessory:
            // Accessories not yet implemented with new system
            break
        }

        return saveAvatarState(newState)
    }

    // MARK: - Private Helpers

    /// Convert AvatarConfiguration to AvatarState
    /// This keeps all Core Data type dependencies within the service layer
    private func avatarState(from configuration: AvatarConfiguration?) -> AvatarState {
        guard let config = configuration else {
            return .default
        }
        return AvatarState(
            skinToneRaw: config.skinTone,
            hairStyleRaw: config.hairStyle,
            hairColorRaw: config.hairColor,
            faceStyleRaw: config.faceStyle,
            jerseyStyleRaw: config.jerseyId,
            shortsStyleRaw: config.shortsId,
            socksStyleRaw: config.socksId,
            cleatsStyleRaw: config.cleatsId
        )
    }

    /// Create default avatar configuration for a new player
    private func createDefaultAvatarConfiguration(for player: Player, context: NSManagedObjectContext) {
        let config = AvatarConfiguration(context: context)
        let defaultState = AvatarState.default

        config.id = UUID()
        config.skinTone = defaultState.skinTone.rawValue
        config.hairStyle = defaultState.hairStyle.rawValue
        config.hairColor = defaultState.hairColor.rawValue
        config.faceStyle = defaultState.faceStyle.rawValue
        config.jerseyId = defaultState.jerseyStyle.rawValue
        config.shortsId = defaultState.shortsStyle.rawValue
        config.socksId = defaultState.socksStyle.rawValue
        config.cleatsId = defaultState.cleatsStyle.rawValue
        config.accessoryIds = [] as NSArray
        config.lastModified = Date()
        config.updatedAt = Date()
        player.avatarConfiguration = config

        do {
            try context.save()
            #if DEBUG
            print("[AvatarService] Created default avatar configuration")
            #endif
        } catch {
            #if DEBUG
            print("[AvatarService] Failed to create default avatar: \(error)")
            #endif
        }
    }
}
