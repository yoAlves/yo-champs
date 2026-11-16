import Foundation

/// Observable output of one engine turn. The shell renders text and maps
/// `state` to mascot animations; the model never names an animation (ADR 0004).
public enum CompanionEvent: Sendable, Equatable {
    case state(CompanionState)
    case textDelta(String)
    case completed
    case cancelled
    /// The message is already user-safe; the shell can show it as-is.
    case failed(String)
}
