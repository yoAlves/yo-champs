import Foundation

/// The Settings model field: a model id with an optional `#effort` suffix.
/// The suffix is input shorthand only; the provider receives `model` and the
/// effort travels as a separate request field.
public struct ModelSelection: Equatable, Sendable {
    public let model: String
    public let effort: String?

    public init(model: String, effort: String?) {
        self.model = model
        self.effort = effort
    }

    public init(parsing raw: String) throws {
        let parts = raw.split(separator: "#", omittingEmptySubsequences: false)
        guard parts.count <= 2 else {
            throw ModelSelectionError.multipleSeparators
        }
        let model = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else {
            throw ModelSelectionError.emptyModel
        }
        if parts.count == 2 {
            let effort = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !effort.isEmpty else {
                throw ModelSelectionError.emptyEffort
            }
            self.init(model: model, effort: effort)
        } else {
            self.init(model: model, effort: nil)
        }
    }

    public var displayString: String {
        guard let effort else {
            return model
        }
        return "\(model)#\(effort)"
    }
}

public enum ModelSelectionError: Error, Sendable, Equatable, CustomStringConvertible {
    case emptyModel
    case emptyEffort
    case multipleSeparators

    public var description: String {
        switch self {
        case .emptyModel:
            "Enter a model id, optionally followed by #effort, e.g. model#low"
        case .emptyEffort:
            "The effort after # is empty; write model#effort or remove the #"
        case .multipleSeparators:
            "Use at most one #: model#effort"
        }
    }
}
