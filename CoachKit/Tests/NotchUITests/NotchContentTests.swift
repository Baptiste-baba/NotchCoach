import Testing
@testable import NotchUI

struct NotchContentTests {
    @Test func emptyContentFoldsThePanel() {
        #expect(NotchContent.empty.isEmpty)
    }

    @Test func aLineOpensThePanel() {
        #expect(!NotchContent(lines: [NotchContent.Line(id: 0, text: "Je comprends.")]).isEmpty)
    }

    @Test func aNoticeAloneOpensThePanel() {
        #expect(!NotchContent(notice: "Lancement de Claude…").isEmpty)
    }
}
