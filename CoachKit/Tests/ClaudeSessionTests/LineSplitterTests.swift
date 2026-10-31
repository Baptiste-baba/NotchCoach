import Foundation
import Testing
@testable import ClaudeSession

struct LineSplitterTests {
    @Test func splitsSeveralLinesInOneChunk() {
        #expect(LineSplitter().append(Data("un\ndeux\n".utf8)) == ["un", "deux"])
    }

    @Test func keepsIncompleteLineUntilItsEnd() {
        let splitter = LineSplitter()

        #expect(splitter.append(Data(#"{"type":"res"#.utf8)) == [])
        #expect(splitter.append(Data("ult\"}\nsuite".utf8)) == [#"{"type":"result"}"#])
        #expect(splitter.append(Data("\n".utf8)) == ["suite"])
    }

    @Test func keepsMultibyteCharacterSplitAcrossChunks() {
        let splitter = LineSplitter()
        let bytes = Array("é\n".utf8)

        #expect(splitter.append(Data(bytes[..<1])) == [])
        #expect(splitter.append(Data(bytes[1...])) == ["é"])
    }

    @Test func doesNotSplitOnUnicodeLineSeparator() {
        #expect(LineSplitter().append(Data("avant\u{2028}après\n".utf8)) == ["avant\u{2028}après"])
    }

    @Test func keepsEmptyLines() {
        #expect(LineSplitter().append(Data("\n\n".utf8)) == ["", ""])
    }
}
