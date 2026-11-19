import Testing
@testable import YoChampsCore

@Suite("ModelSelection")
struct ModelSelectionTests {
    @Test("parses a bare model id")
    func parsesABareModel() throws {
        let selection = try ModelSelection(parsing: "deepseek-v4.1-flash")
        #expect(selection.model == "deepseek-v4.1-flash")
        #expect(selection.effort == nil)
        #expect(selection.displayString == "deepseek-v4.1-flash")
    }

    @Test("parses an effort suffix")
    func parsesAnEffortSuffix() throws {
        let selection = try ModelSelection(parsing: "deepseek-v4.1-flash#low")
        #expect(selection.model == "deepseek-v4.1-flash")
        #expect(selection.effort == "low")
        #expect(selection.displayString == "deepseek-v4.1-flash#low")
    }

    @Test("trims the model and the effort")
    func trimsModelAndEffort() throws {
        let selection = try ModelSelection(parsing: " deepseek-v4.1-flash # low ")
        #expect(selection.model == "deepseek-v4.1-flash")
        #expect(selection.effort == "low")
    }

    @Test("rejects an empty model")
    func rejectsAnEmptyModel() {
        #expect(throws: ModelSelectionError.emptyModel) { try ModelSelection(parsing: "   ") }
        #expect(throws: ModelSelectionError.emptyModel) { try ModelSelection(parsing: "#low") }
    }

    @Test("rejects an empty effort")
    func rejectsAnEmptyEffort() {
        #expect(throws: ModelSelectionError.emptyEffort) { try ModelSelection(parsing: "model#") }
        #expect(throws: ModelSelectionError.emptyEffort) { try ModelSelection(parsing: "model#   ") }
    }

    @Test("rejects more than one separator")
    func rejectsMultipleSeparators() {
        #expect(throws: ModelSelectionError.multipleSeparators) { try ModelSelection(parsing: "a#b#c") }
    }
}
