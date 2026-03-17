import Foundation

// MARK: - CustomDrillService Protocol

@MainActor
protocol CustomDrillServiceProtocol: AnyObject {
    var generationState: DrillGenerationState { get }
    var isGenerating: Bool { get }
    var generationProgress: Double { get }
    var generationMessage: String { get }

    func generateCustomDrill(request: CustomDrillRequest, for player: Player) async throws -> Exercise
}
