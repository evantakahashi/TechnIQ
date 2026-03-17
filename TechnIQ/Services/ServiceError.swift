import Foundation

enum ServiceError: LocalizedError {
    case network(String)
    case coreData(String)
    case validation(String)
    case sync(String)
    case auth(String)
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .network(let msg): return "Network error: \(msg)"
        case .coreData(let msg): return "Data error: \(msg)"
        case .validation(let msg): return "Validation error: \(msg)"
        case .sync(let msg): return "Sync error: \(msg)"
        case .auth(let msg): return "Authentication error: \(msg)"
        case .notFound(let msg): return "\(msg) not found"
        }
    }
}
