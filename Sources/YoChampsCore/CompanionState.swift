import Foundation

/// Semantic companion states. The renderer maps these to mascot animations;
/// the model never names an animation directly (see ADR 0004).
public enum CompanionState: String, Codable, Sendable, CaseIterable {
    case idle
    case thinking
    case streaming
    case happy
    case confused
    case error
}

extension CompanionState: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}
