import Foundation
import CoreData
import Combine

/// Service for managing player avatar configuration and inventory
final class AvatarService: ObservableObject {
    static let shared = AvatarService()

    // MARK: - Published Properties

    /// Current avatar state (for reactive UI updates)
    @Published private(set) var currentAvatarState: AvatarState = .default

    /// Set of item IDs that the player owns
    @Published private(set) var ownedItemIds: Set<String> = []

    // MARK: - Private Properties

    private let coreDataManager = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadCurrentAvatar()
        loadOwnedItems()
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

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentAvatarState = self.avatarState(from: player.avatarConfiguration)
        }
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

        do {
            try ctx.save()

            DispatchQueue.main.async { [weak self] in
                self?.currentAvatarState = avatarState
            }

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

    // MARK: - Inventory Management

    /// Load owned items from Core Data
    func loadOwnedItems() {
        let context = coreDataManager.context
        guard let player = coreDataManager.getCurrentPlayer() else {
            ownedItemIds = starterItemIds
            return
        }

        var items = starterItemIds
        if let ownedItems = player.ownedAvatarItems as? Set<OwnedAvatarItem> {
            for item in ownedItems {
                if let itemId = item.itemId {
                    items.insert(itemId)
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.ownedItemIds = items
        }
    }

    /// Check if player owns an item
    func ownsItem(_ itemId: String) -> Bool {
        // Starter items are always owned
        if starterItemIds.contains(itemId) {
            return true
        }
        return ownedItemIds.contains(itemId)
    }

    /// Add an item to player's inventory (after purchase)
    /// - Parameters:
    ///   - itemId: The item ID to add
    ///   - context: Core Data context
    /// - Returns: True if successful
    @discardableResult
    func addItemToInventory(_ itemId: String, context: NSManagedObjectContext? = nil) -> Bool {
        let ctx = context ?? coreDataManager.context
        guard let player = coreDataManager.getCurrentPlayer() else {
            #if DEBUG
            print("[AvatarService] No player found to add item")
            #endif
            return false
        }

        // Check if already owned
        if ownsItem(itemId) {
            #if DEBUG
            print("[AvatarService] Item already owned: \(itemId)")
            #endif
            return true
        }

        // Create owned item record
        let ownedItem = OwnedAvatarItem(context: ctx)
        ownedItem.id = UUID()
        ownedItem.itemId = itemId
        ownedItem.purchasedAt = Date()
        ownedItem.player = player

        do {
            try ctx.save()

            DispatchQueue.main.async { [weak self] in
                self?.ownedItemIds.insert(itemId)
            }

            #if DEBUG
            print("[AvatarService] Item added to inventory: \(itemId)")
            #endif
            return true
        } catch {
            #if DEBUG
            print("[AvatarService] Failed to add item: \(error)")
            #endif
            ctx.rollback()
            return false
        }
    }

    /// Get all owned items for a specific slot
    func ownedItems(for slot: AvatarSlot) -> [String] {
        let catalog = AvatarCatalogService.shared
        return catalog.items(for: slot)
            .filter { ownsItem($0.id) }
            .map { $0.id }
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

    /// IDs of items that are free for all players (starters)
    private var starterItemIds: Set<String> {
        Set([
            // Starter jerseys (matches JerseyStyle enum raw values)
            JerseyStyle.starterGreen.rawValue,
            // Starter shorts (matches ShortsStyle enum raw values)
            ShortsStyle.starterWhite.rawValue,
            // Starter socks (matches SocksStyle enum raw values)
            SocksStyle.greenStriped.rawValue,
            // Starter cleats (matches CleatsStyle enum raw values)
            CleatsStyle.starterGreen.rawValue,
            // Starter hair styles (matches HairStyle enum raw values)
            HairStyle.shortWavy.rawValue,
            HairStyle.buzzCut.rawValue,
            HairStyle.crewCut.rawValue
        ])
    }
}

// MARK: - Avatar Catalog Service

/// Service providing the catalog of available avatar items
final class AvatarCatalogService {
    static let shared = AvatarCatalogService()

    private init() {}

    /// All available items in the catalog
    let allItems: [AvatarItem] = [
        // MARK: - Starter Items (Free)

        // Jerseys - Starter
        AvatarItem(
            id: "starter_jersey",
            name: "Training Jersey",
            slot: .jersey,
            rarity: .starter,
            price: 0,
            assetName: "starter",
            description: "Your basic training jersey. Simple but effective.",
            levelRequirement: 0
        ),
        AvatarItem(
            id: "jersey_white_basic",
            name: "White Practice Jersey",
            slot: .jersey,
            rarity: .starter,
            price: 0,
            assetName: "white_basic",
            description: "Clean white jersey for scrimmages.",
            levelRequirement: 0
        ),

        // Shorts - Starter
        AvatarItem(
            id: "starter_shorts",
            name: "Training Shorts",
            slot: .shorts,
            rarity: .starter,
            price: 0,
            assetName: "starter",
            description: "Comfortable shorts for everyday training.",
            levelRequirement: 0
        ),
        AvatarItem(
            id: "shorts_black_basic",
            name: "Black Practice Shorts",
            slot: .shorts,
            rarity: .starter,
            price: 0,
            assetName: "black_basic",
            description: "Classic black shorts.",
            levelRequirement: 0
        ),

        // Cleats - Starter
        AvatarItem(
            id: "starter_cleats",
            name: "Training Cleats",
            slot: .cleats,
            rarity: .starter,
            price: 0,
            assetName: "starter",
            description: "Basic cleats to get you started.",
            levelRequirement: 0
        ),
        AvatarItem(
            id: "cleats_black_basic",
            name: "Black Cleats",
            slot: .cleats,
            rarity: .starter,
            price: 0,
            assetName: "black_basic",
            description: "Simple black cleats.",
            levelRequirement: 0
        ),

        // Hair - Starter
        AvatarItem(
            id: "short_1",
            name: "Short Cut",
            slot: .hairStyle,
            rarity: .starter,
            price: 0,
            assetName: "short_1",
            description: "Classic short hairstyle.",
            levelRequirement: 0
        ),
        AvatarItem(
            id: "short_2",
            name: "Crew Cut",
            slot: .hairStyle,
            rarity: .starter,
            price: 0,
            assetName: "short_2",
            description: "Neat and tidy crew cut.",
            levelRequirement: 0
        ),
        AvatarItem(
            id: "medium_1",
            name: "Medium Length",
            slot: .hairStyle,
            rarity: .starter,
            price: 0,
            assetName: "medium_1",
            description: "Versatile medium-length style.",
            levelRequirement: 0
        ),

        // MARK: - Common Items (50-150 coins)

        // Jerseys - Common
        AvatarItem(
            id: "jersey_blue",
            name: "Blue Jersey",
            slot: .jersey,
            rarity: .common,
            price: 75,
            assetName: "blue",
            description: "Cool blue team jersey.",
            levelRequirement: 0
        ),
        AvatarItem(
            id: "jersey_red",
            name: "Red Jersey",
            slot: .jersey,
            rarity: .common,
            price: 75,
            assetName: "red",
            description: "Bold red team jersey.",
            levelRequirement: 0
        ),
        AvatarItem(
            id: "jersey_yellow",
            name: "Yellow Jersey",
            slot: .jersey,
            rarity: .common,
            price: 75,
            assetName: "yellow",
            description: "Bright yellow jersey.",
            levelRequirement: 0
        ),
        AvatarItem(
            id: "jersey_black",
            name: "Black Jersey",
            slot: .jersey,
            rarity: .common,
            price: 100,
            assetName: "black",
            description: "Sleek black jersey.",
            levelRequirement: 0
        ),

        // Shorts - Common
        AvatarItem(
            id: "shorts_white",
            name: "White Shorts",
            slot: .shorts,
            rarity: .common,
            price: 50,
            assetName: "white",
            description: "Clean white shorts.",
            levelRequirement: 0
        ),
        AvatarItem(
            id: "shorts_blue",
            name: "Blue Shorts",
            slot: .shorts,
            rarity: .common,
            price: 50,
            assetName: "blue",
            description: "Blue athletic shorts.",
            levelRequirement: 0
        ),

        // Cleats - Common
        AvatarItem(
            id: "cleats_white",
            name: "White Cleats",
            slot: .cleats,
            rarity: .common,
            price: 100,
            assetName: "white",
            description: "Fresh white cleats.",
            levelRequirement: 0
        ),
        AvatarItem(
            id: "cleats_blue",
            name: "Blue Cleats",
            slot: .cleats,
            rarity: .common,
            price: 100,
            assetName: "blue",
            description: "Blue performance cleats.",
            levelRequirement: 0
        ),

        // Hair - Common
        AvatarItem(
            id: "short_3",
            name: "Fade Cut",
            slot: .hairStyle,
            rarity: .common,
            price: 75,
            assetName: "short_3",
            description: "Stylish fade haircut.",
            levelRequirement: 0
        ),
        AvatarItem(
            id: "medium_2",
            name: "Wavy Medium",
            slot: .hairStyle,
            rarity: .common,
            price: 75,
            assetName: "medium_2",
            description: "Natural wavy style.",
            levelRequirement: 0
        ),

        // Accessories - Common
        AvatarItem(
            id: "headband_white",
            name: "White Headband",
            slot: .accessory,
            rarity: .common,
            price: 50,
            assetName: "headband_white",
            description: "Classic white headband.",
            levelRequirement: 0
        ),
        AvatarItem(
            id: "wristband_left",
            name: "Wristband",
            slot: .accessory,
            rarity: .common,
            price: 40,
            assetName: "wristband",
            description: "Athletic wristband.",
            levelRequirement: 0
        ),

        // MARK: - Uncommon Items (200-400 coins, Level 5+)

        // Jerseys - Uncommon
        AvatarItem(
            id: "jersey_stripes",
            name: "Striped Jersey",
            slot: .jersey,
            rarity: .uncommon,
            price: 250,
            assetName: "stripes",
            description: "Classic striped design.",
            levelRequirement: 5
        ),
        AvatarItem(
            id: "jersey_gradient",
            name: "Gradient Jersey",
            slot: .jersey,
            rarity: .uncommon,
            price: 300,
            assetName: "gradient",
            description: "Modern gradient effect.",
            levelRequirement: 5
        ),

        // Hair - Uncommon
        AvatarItem(
            id: "long_1",
            name: "Long Hair",
            slot: .hairStyle,
            rarity: .uncommon,
            price: 200,
            assetName: "long_1",
            description: "Flowing long hair.",
            levelRequirement: 5
        ),
        AvatarItem(
            id: "ponytail",
            name: "Ponytail",
            slot: .hairStyle,
            rarity: .uncommon,
            price: 200,
            assetName: "ponytail",
            description: "Practical ponytail style.",
            levelRequirement: 5
        ),
        AvatarItem(
            id: "afro",
            name: "Afro",
            slot: .hairStyle,
            rarity: .uncommon,
            price: 250,
            assetName: "afro",
            description: "Proud afro hairstyle.",
            levelRequirement: 5
        ),

        // Accessories - Uncommon
        AvatarItem(
            id: "captain_armband",
            name: "Captain's Armband",
            slot: .accessory,
            rarity: .uncommon,
            price: 300,
            assetName: "captain_armband",
            description: "Lead your team with pride!",
            levelRequirement: 5
        ),
        AvatarItem(
            id: "headband_black",
            name: "Black Headband",
            slot: .accessory,
            rarity: .uncommon,
            price: 200,
            assetName: "headband_black",
            description: "Sleek black headband.",
            levelRequirement: 5
        ),

        // MARK: - Rare Items (500-800 coins, Level 15+)

        // Jerseys - Rare
        AvatarItem(
            id: "jersey_flames",
            name: "Flames Jersey",
            slot: .jersey,
            rarity: .rare,
            price: 600,
            assetName: "flames",
            description: "Fiery flame design.",
            levelRequirement: 15
        ),
        AvatarItem(
            id: "jersey_electric",
            name: "Electric Jersey",
            slot: .jersey,
            rarity: .rare,
            price: 650,
            assetName: "electric",
            description: "Lightning bolt pattern.",
            levelRequirement: 15
        ),

        // Cleats - Rare
        AvatarItem(
            id: "cleats_gold",
            name: "Gold Cleats",
            slot: .cleats,
            rarity: .rare,
            price: 700,
            assetName: "gold",
            description: "Gleaming gold cleats.",
            levelRequirement: 15
        ),
        AvatarItem(
            id: "cleats_neon",
            name: "Neon Cleats",
            slot: .cleats,
            rarity: .rare,
            price: 550,
            assetName: "neon",
            description: "Eye-catching neon cleats.",
            levelRequirement: 15
        ),

        // Hair - Rare
        AvatarItem(
            id: "mohawk",
            name: "Mohawk",
            slot: .hairStyle,
            rarity: .rare,
            price: 500,
            assetName: "mohawk",
            description: "Bold mohawk style.",
            levelRequirement: 15
        ),

        // Accessories - Rare
        AvatarItem(
            id: "sunglasses",
            name: "Sports Sunglasses",
            slot: .accessory,
            rarity: .rare,
            price: 600,
            assetName: "sunglasses",
            description: "Cool sports shades.",
            levelRequirement: 15
        ),

        // MARK: - Epic Items (1000-2000 coins, Level 25+)

        // Jerseys - Epic
        AvatarItem(
            id: "jersey_galaxy",
            name: "Galaxy Jersey",
            slot: .jersey,
            rarity: .epic,
            price: 1500,
            assetName: "galaxy",
            description: "Out-of-this-world cosmic design.",
            levelRequirement: 25
        ),

        // Cleats - Epic
        AvatarItem(
            id: "cleats_diamond",
            name: "Diamond Cleats",
            slot: .cleats,
            rarity: .epic,
            price: 1800,
            assetName: "diamond",
            description: "Sparkling diamond-studded cleats.",
            levelRequirement: 25
        ),

        // Accessories - Epic
        AvatarItem(
            id: "chain_gold",
            name: "Gold Chain",
            slot: .accessory,
            rarity: .epic,
            price: 1200,
            assetName: "chain_gold",
            description: "Flashy gold chain.",
            levelRequirement: 25
        ),

        // MARK: - Legendary Items (2500+ coins, Level 40+)

        // Accessories - Legendary
        AvatarItem(
            id: "crown",
            name: "Champion's Crown",
            slot: .accessory,
            rarity: .legendary,
            price: 3500,
            assetName: "crown",
            description: "Rule the pitch like royalty!",
            levelRequirement: 40
        ),
        AvatarItem(
            id: "trophy_necklace",
            name: "Trophy Pendant",
            slot: .accessory,
            rarity: .legendary,
            price: 5000,
            assetName: "trophy_necklace",
            description: "A miniature trophy around your neck.",
            levelRequirement: 40
        ),
    ]

    /// Get items filtered by slot
    func items(for slot: AvatarSlot) -> [AvatarItem] {
        allItems.filter { $0.slot == slot }
    }

    /// Get items filtered by rarity
    func items(of rarity: ItemRarity) -> [AvatarItem] {
        allItems.filter { $0.rarity == rarity }
    }

    /// Get items available at a given level
    func itemsAvailable(atLevel level: Int) -> [AvatarItem] {
        allItems.filter { $0.levelRequirement <= level }
    }

    /// Get items for the shop (excludes starters, grouped by rarity)
    func shopItems(forLevel level: Int) -> [ItemRarity: [AvatarItem]] {
        var result: [ItemRarity: [AvatarItem]] = [:]

        for rarity in ItemRarity.allCases where rarity != .starter {
            let items = allItems.filter {
                $0.rarity == rarity && $0.levelRequirement <= level
            }
            if !items.isEmpty {
                result[rarity] = items
            }
        }

        return result
    }

    /// Find an item by ID
    func item(withId id: String) -> AvatarItem? {
        allItems.first { $0.id == id }
    }
}
