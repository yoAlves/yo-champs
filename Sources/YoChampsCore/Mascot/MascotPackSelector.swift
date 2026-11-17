import Foundation

/// A mascot pack discovered on disk, with validation already performed by the
/// caller. Core performs no I/O: the Mac loader enumerates directories and maps
/// validator failures into `validationError` before calling `select`.
public struct MascotPackCandidate: Sendable, Equatable {
    public let id: String
    public let name: String
    public let directory: URL
    public let validationError: String?

    public init(id: String, name: String, directory: URL, validationError: String?) {
        self.id = id
        self.name = name
        self.directory = directory
        self.validationError = validationError
    }
}

/// The outcome of choosing among locally discovered mascot packs. Errors are
/// described with user-facing strings so Settings can display them verbatim.
public enum MascotPackSelection: Sendable, Equatable {
    case `default`
    case local(MascotPackCandidate)
    case invalidLocal(reason: String)
    case ambiguous(count: Int)
}

/// Pure rules for picking a local pack: validation errors take precedence,
/// otherwise zero/one/many candidates decide the result.
public enum MascotPackSelector {
    public static func select(localPacks: [MascotPackCandidate]) -> MascotPackSelection {
        if let invalid = localPacks.first(where: { $0.validationError != nil }) {
            let reason = invalid.validationError ?? ""
            return .invalidLocal(reason: "Local pack '\(invalid.name)' is invalid: \(reason)")
        }

        switch localPacks.count {
        case 0:
            return .default
        case 1:
            return .local(localPacks[0])
        default:
            return .ambiguous(count: localPacks.count)
        }
    }
}
