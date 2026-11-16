import Testing
@testable import YoChampsProviders

@Suite("SSE decoder")
struct SSEDecoderTests {
    private func feed(_ text: String) -> [UInt8] {
        Array(text.utf8)
    }

    @Test("dispatches a data line on the blank line")
    func singleEvent() {
        var decoder = SSEDecoder()
        #expect(decoder.feed(feed("data: hello\n\n")) == [.data("hello")])
    }

    @Test("joins multiline data with newlines")
    func multilineData() {
        var decoder = SSEDecoder()
        #expect(decoder.feed(feed("data: one\ndata: two\n\n")) == [.data("one\ntwo")])
    }

    @Test("recognises the done sentinel")
    func doneSentinel() {
        var decoder = SSEDecoder()
        #expect(decoder.feed(feed("data: [DONE]\n\n")) == [.done])
    }

    @Test("holds partial bytes until the line is complete")
    func partialBytes() {
        var decoder = SSEDecoder()
        #expect(decoder.feed(feed("data: hel")) == [])
        #expect(decoder.feed(feed("lo\n\n")) == [.data("hello")])
    }

    @Test("accepts CRLF and ignores comments and non-data fields")
    func crlfAndComments() {
        var decoder = SSEDecoder()
        let chunk = ": keepalive\nevent: message\nid: 7\ndata: x\r\n\r\n"
        #expect(decoder.feed(feed(chunk)) == [.data("x")])
    }

    @Test("dispatches every event in a chunk")
    func multipleEvents() {
        var decoder = SSEDecoder()
        let chunk = "data: a\n\ndata: b\n\ndata: [DONE]\n\n"
        #expect(decoder.feed(feed(chunk)) == [.data("a"), .data("b"), .done])
    }

    @Test("flushes an event left without a trailing blank line")
    func flushOnFinish() {
        var decoder = SSEDecoder()
        #expect(decoder.feed(feed("data: tail\n")) == [])
        #expect(decoder.finish() == [.data("tail")])
    }

    @Test("preserves multibyte UTF-8 split across chunks")
    func splitUTF8() throws {
        var decoder = SSEDecoder()
        let bytes = feed("data: café\n\n")
        let splitIndex = try #require(bytes.firstIndex(of: 0xC3))
        #expect(decoder.feed(Array(bytes[..<splitIndex])) == [])
        #expect(decoder.feed(Array(bytes[splitIndex...])) == [.data("café")])
    }
}
