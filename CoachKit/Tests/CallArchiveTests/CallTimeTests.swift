import Foundation
import Testing
@testable import CallArchive

struct CallTimeTests {
    @Test(arguments: [(0.0, "00:00"), (47.9, "00:47"), (252.0, "04:12"), (3852.0, "1:04:12"), (-3.0, "00:00")] as [(TimeInterval, String)])
    func labelShowsMinutesAndSeconds(seconds: TimeInterval, label: String) {
        #expect(CallTime.label(seconds) == label)
    }

    @Test(arguments: [("04:12", 252.0), ("1:04:12", 3852.0), (" 00:47 ", 47.0)] as [(String, TimeInterval)])
    func labelIsReadBackAsSeconds(label: String, seconds: TimeInterval) {
        #expect(CallTime.seconds(from: label) == seconds)
    }

    @Test(arguments: ["", "12", "4h12", "04:60", "1:2:3:4", "-1:00", "aa:bb"])
    func whatIsNotALabelGivesNoMoment(text: String) {
        #expect(CallTime.seconds(from: text) == nil)
    }
}
