import Foundation

public enum SSEEvent: Sendable, Equatable {
    case data(String)
    case done
}

/// Incremental server-sent-events decoder. Bytes may arrive split anywhere:
/// lines are decoded only once their newline arrives, so a multibyte character
/// is never decoded in two halves.
public struct SSEDecoder: Sendable {
    private var pendingBytes: [UInt8] = []
    private var dataLines: [String] = []

    public init() {}

    /// Feeds raw bytes and returns the events completed by this chunk.
    public mutating func feed(_ bytes: [UInt8]) -> [SSEEvent] {
        var events: [SSEEvent] = []
        for byte in bytes {
            if byte == 0x0A {
                let line = pendingBytes
                pendingBytes.removeAll(keepingCapacity: true)
                accept(line, into: &events)
            } else {
                pendingBytes.append(byte)
            }
        }
        return events
    }

    /// Flushes a trailing line and any event left without a blank line.
    public mutating func finish() -> [SSEEvent] {
        var events: [SSEEvent] = []
        if !pendingBytes.isEmpty {
            let line = pendingBytes
            pendingBytes.removeAll(keepingCapacity: true)
            accept(line, into: &events)
        }
        dispatch(into: &events)
        return events
    }

    private mutating func accept(_ bytes: [UInt8], into events: inout [SSEEvent]) {
        guard !bytes.isEmpty else {
            dispatch(into: &events)
            return
        }
        var line = String(bytes: bytes, encoding: .utf8) ?? ""
        if line.hasSuffix("\r") {
            line.removeLast()
        }
        guard !line.isEmpty else {
            dispatch(into: &events)
            return
        }
        guard !line.hasPrefix(":"), line.hasPrefix("data:") else { return }

        var value = String(line.dropFirst(5))
        if value.hasPrefix(" ") {
            value.removeFirst()
        }
        dataLines.append(value)
    }

    private mutating func dispatch(into events: inout [SSEEvent]) {
        guard !dataLines.isEmpty else { return }
        let value = dataLines.joined(separator: "\n")
        dataLines.removeAll(keepingCapacity: true)
        events.append(value == "[DONE]" ? .done : .data(value))
    }
}
