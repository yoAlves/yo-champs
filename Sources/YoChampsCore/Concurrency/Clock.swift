import Foundation

/// Injectable sleep used to pace streaming and to keep timing deterministic in
/// tests. Deliberately narrower than the standard library `Clock`: callers
/// only need to wait, and a test double only needs to intercept that wait.
public protocol Clock: Sendable {
    func sleep(for duration: Duration) async throws
}

/// Production clock backed by `Task.sleep`.
public struct SystemClock: Clock {
    public init() {}

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
