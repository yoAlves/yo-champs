import Foundation
import Testing
@testable import YoChampsCore

@Suite("MascotPackSelector")
struct MascotPackSelectorTests {
    private func candidate(
        id: String = "test",
        name: String = "Test Pack",
        directory: String = "/Mascots/test",
        validationError: String? = nil
    ) -> MascotPackCandidate {
        MascotPackCandidate(
            id: id,
            name: name,
            directory: URL(fileURLWithPath: directory),
            validationError: validationError
        )
    }

    @Test("no local packs selects the default")
    func noPacksUsesDefault() {
        #expect(MascotPackSelector.select(localPacks: []) == .default)
    }

    @Test("a single valid pack is selected")
    func singleValidPack() {
        let pack = candidate(id: "champ", name: "Champ", directory: "/Mascots/champ")
        #expect(MascotPackSelector.select(localPacks: [pack]) == .local(pack))
    }

    @Test("an invalid pack reports a clear reason")
    func invalidPackReportsReason() {
        let message = "missing file: /Mascots/broken/preview.png"
        let pack = candidate(
            id: "broken",
            name: "Broken Pack",
            directory: "/Mascots/broken",
            validationError: message
        )

        guard case let .invalidLocal(reason) = MascotPackSelector.select(localPacks: [pack]) else {
            Issue.record("expected .invalidLocal, got \(MascotPackSelector.select(localPacks: [pack]))")
            return
        }
        #expect(reason.contains("Broken Pack"))
        #expect(reason.contains(message))
    }

    @Test("two valid packs are ambiguous")
    func twoValidPacksAreAmbiguous() {
        let first = candidate(id: "first", name: "First", directory: "/Mascots/first")
        let second = candidate(id: "second", name: "Second", directory: "/Mascots/second")
        #expect(MascotPackSelector.select(localPacks: [first, second]) == .ambiguous(count: 2))
    }

    @Test("ambiguity reports the number of valid packs")
    func ambiguityCountScales() {
        let packs = (1 ... 3).map {
            candidate(id: "pack\($0)", name: "Pack \($0)", directory: "/Mascots/pack\($0)")
        }
        #expect(MascotPackSelector.select(localPacks: packs) == .ambiguous(count: 3))
    }

    @Test("validation errors take precedence over valid packs and ambiguity")
    func validationErrorTakesPrecedence() {
        let valid = candidate(id: "good", name: "Good", directory: "/Mascots/good")
        let invalid = candidate(
            id: "bad",
            name: "Bad",
            directory: "/Mascots/bad",
            validationError: "bad manifest"
        )
        let anotherValid = candidate(id: "good2", name: "Good 2", directory: "/Mascots/good2")

        for packs in [[valid, invalid], [invalid, valid], [valid, anotherValid, invalid]] {
            guard case .invalidLocal = MascotPackSelector.select(localPacks: packs) else {
                Issue.record("expected .invalidLocal, got \(MascotPackSelector.select(localPacks: packs))")
                return
            }
        }
    }

    @Test("the first invalid pack reason is reported deterministically")
    func firstInvalidReasonWins() {
        let first = candidate(
            id: "first",
            name: "First",
            directory: "/Mascots/first",
            validationError: "first error"
        )
        let second = candidate(
            id: "second",
            name: "Second",
            directory: "/Mascots/second",
            validationError: "second error"
        )

        guard case let .invalidLocal(reason) = MascotPackSelector.select(localPacks: [first, second]) else {
            Issue.record("expected .invalidLocal")
            return
        }
        #expect(reason.contains("First"))
        #expect(reason.contains("first error"))
        #expect(!reason.contains("second error"))
    }
}
